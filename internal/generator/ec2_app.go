package generator

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/PydaVi/brainctl/internal/config"
)

const mainTF = `
terraform {
  required_version = ">= 1.6.0"
  backend "s3" {
    bucket       = "brainctl-terraform-states"
    key          = "{{ .App.Name }}/{{ .App.Environment }}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "{{ .App.Region }}"
}

module "app" {
  source = "./modules/ec2-app"

  name        = "{{ .App.Name }}"
  environment = "{{ .App.Environment }}"
  region      = "{{ .App.Region }}"

  vpc_id    = "{{ .Infrastructure.VpcID }}"
  subnet_id = "{{ .Infrastructure.SubnetID }}"

  instance_type    = "{{ .EC2.InstanceType }}"
  allowed_rdp_cidr = "0.0.0.0/0"

  enable_db        = {{ .DB.Enabled }}
  db_instance_type = "{{ .DB.InstanceType }}"
  db_port          = {{ .DB.Port }}

  enable_lb        = {{ .LB.Enabled }}
  lb_scheme        = "{{ .LB.Scheme }}"
  lb_subnet_ids    = [{{- range $i, $s := .LB.SubnetIDs -}}{{- if $i }}, {{ end }}"{{ $s }}"{{- end -}}]

  lb_listener_port = {{ .LB.ListenerPort }}
  app_port         = {{ .LB.TargetPort }}
  lb_allowed_cidr  = "{{ .LB.AllowedCIDR }}"
}
`

const outputsTF = `
output "instance_id" {
  value       = module.app.instance_id
  description = "EC2 instance id"
}

output "private_ip" {
  value       = module.app.private_ip
  description = "EC2 private ip"
}

output "public_ip" {
  value       = module.app.public_ip
  description = "EC2 public ip"
}

output "security_group_id" {
  value       = module.app.security_group_id
  description = "App SG id"
}

output "security_group_name" {
  value       = module.app.security_group_name
  description = "App SG name"
}

output "db_instance_id" {
  value       = module.app.db_instance_id
  description = "DB instance id"
}

output "db_private_ip" {
  value       = module.app.db_private_ip
  description = "DB private ip"
}

output "db_security_group_id" {
  value       = module.app.db_security_group_id
  description = "DB SG id"
}

output "db_security_group_name" {
  value       = module.app.db_security_group_name
  description = "DB SG name"
}

output "alb_dns_name" {
  value       = module.app.alb_dns_name
  description = "ALB DNS name"
}

# (opcionais, mas úteis)
output "alb_arn" {
  value       = module.app.alb_arn
  description = "ALB ARN"
}

output "alb_target_group_arn" {
  value       = module.app.alb_target_group_arn
  description = "ALB Target Group ARN"
}
`

func GenerateEC2App(wsDir string, cfg *config.AppConfig) error {
	// 1) Copiar o módulo Terraform para dentro do workspace
	repoRoot, err := findRepoRoot()
	if err != nil {
		return fmt.Errorf("find repo root: %w", err)
	}

	srcModuleDir := filepath.Join(repoRoot, "terraform-modulesec2-app")
	dstModuleDir := filepath.Join(wsDir, "modules", "ec2-app")

	if err := copyDir(srcModuleDir, dstModuleDir); err != nil {
		return fmt.Errorf("copy module dir: %w", err)
	}

	// 2) Renderizar main.tf dentro do workspace
	mainTFPath := filepath.Join(wsDir, "main.tf")

	tpl, err := template.New("main.tf").Parse(mainTF)
	if err != nil {
		return fmt.Errorf("parse template: %w", err)
	}

	f, err := os.Create(mainTFPath)
	if err != nil {
		return fmt.Errorf("create main.tf: %w", err)
	}
	defer f.Close()

	if err := tpl.Execute(f, cfg); err != nil {
		return fmt.Errorf("render template: %w", err)
	}

	// 3) outputs.tf (root outputs)
	outPath := filepath.Join(wsDir, "outputs.tf")
	if err := os.WriteFile(outPath, []byte(outputsTF), 0644); err != nil {
		return fmt.Errorf("create outputs.tf: %w", err)
	}

	return nil
}

// findRepoRoot sobe diretórios a partir do cwd até achar um go.mod.
func findRepoRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	dir := cwd
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", fmt.Errorf("could not find go.mod starting from %q (walked up to filesystem root)", cwd)
}

func copyDir(src, dst string) error {
	src = filepath.Clean(src)
	dst = filepath.Clean(dst)

	info, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("stat src: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("src is not a directory: %s", src)
	}

	// recria destino do zero (evita lixo/arquivos antigos)
	if err := os.RemoveAll(dst); err != nil {
		return fmt.Errorf("remove dst: %w", err)
	}
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return fmt.Errorf("mkdir dst: %w", err)
	}

	return filepath.WalkDir(src, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}

		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		rel = filepath.Clean(rel)
		if strings.HasPrefix(rel, "..") {
			return fmt.Errorf("invalid relative path during copy: %q", rel)
		}

		targetPath := filepath.Join(dst, rel)

		if d.IsDir() {
			if rel == "." {
				return nil
			}
			return os.MkdirAll(targetPath, 0o755)
		}

		// não copia symlink
		if d.Type()&os.ModeSymlink != 0 {
			return nil
		}

		return copyFile(path, targetPath)
	})
}

func copyFile(srcFile, dstFile string) error {
	in, err := os.Open(srcFile)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dstFile), 0o755); err != nil {
		return err
	}

	out, err := os.Create(dstFile)
	if err != nil {
		return err
	}
	defer func() { _ = out.Close() }()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	return out.Sync()
}
