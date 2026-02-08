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

  instance_type      = "{{ .EC2.InstanceType }}"
  allowed_rdp_cidr   = "0.0.0.0/0"
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

	return nil
}

// findRepoRoot sobe diretórios a partir do cwd até achar um go.mod.
// Isso permite rodar o brainctl de qualquer subpasta (e.g. ./cmd/brainctl).
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
		// segurança: não permitir escapar do destino
		rel = filepath.Clean(rel)
		if strings.HasPrefix(rel, "..") {
			return fmt.Errorf("invalid relative path during copy: %q", rel)
		}

		targetPath := filepath.Join(dst, rel)

		if d.IsDir() {
			// mantém permissões básicas
			if rel == "." {
				return nil
			}
			return os.MkdirAll(targetPath, 0o755)
		}

		// evita copiar symlink (pra não dar surpresa)
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
	defer func() {
		_ = out.Close()
	}()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	return out.Sync()
}
