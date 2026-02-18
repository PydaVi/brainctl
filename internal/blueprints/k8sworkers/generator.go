package k8sworkers

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"text/template"

	"github.com/PydaVi/brainctl/internal/config"
)

const mainTF = `
terraform {
  required_version = ">= 1.6.0"
  backend "s3" {
    bucket       = "pydavi-terraform-state"
    key          = "{{ .App.Name }}/{{ .App.Environment }}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "{{ .App.Region }}"
}

module "k8s_workers" {
  source = "./modules/k8s-workers"

  name        = "{{ .App.Name }}"
  environment = "{{ .App.Environment }}"
  region      = "{{ .App.Region }}"

  vpc_id                 = "{{ .Infrastructure.VpcID }}"
  subnet_id              = "{{ .Infrastructure.SubnetID }}"
  endpoint_subnet_ids    = [{{- range $i, $s := .EndpointSubnetIDs -}}{{- if $i }}, {{ end }}"{{ $s }}"{{- end -}}]
  control_plane_ami      = "{{ .K8s.ControlPlaneAMI }}"
  worker_ami             = "{{ .K8s.WorkerAMI }}"
  control_plane_type     = "{{ .K8s.ControlPlaneInstanceType }}"
  worker_type            = "{{ .K8s.WorkerInstanceType }}"
  worker_count           = {{ .K8s.WorkerCount }}
  kubernetes_version     = "{{ .K8s.KubernetesVersion }}"
  pod_cidr               = "{{ .K8s.PodCIDR }}"
  key_name               = "{{ .K8s.KeyName }}"
  admin_cidr             = "{{ .K8s.AdminCIDR }}"
  enable_ssm               = {{ .EnableSSM }}
  enable_ssm_vpc_endpoints = {{ .EnableSSMVPCEndpoints }}
  enable_detailed_monitoring = {{ .EnableDetailedMonitoring }}
}
`

const outputsTF = `
output "control_plane_instance_id" {
  value       = module.k8s_workers.control_plane_instance_id
  description = "EC2 id do control-plane"
}

output "control_plane_private_ip" {
  value       = module.k8s_workers.control_plane_private_ip
  description = "IP privado do control-plane"
}

output "control_plane_public_ip" {
  value       = module.k8s_workers.control_plane_public_ip
  description = "IP público do control-plane"
}

output "control_plane_public_dns" {
  value       = module.k8s_workers.control_plane_public_dns
  description = "DNS público do control-plane"
}

output "worker_instance_ids" {
  value       = module.k8s_workers.worker_instance_ids
  description = "IDs das instâncias worker"
}

output "kubeconfig_retrieve_instructions" {
  value       = module.k8s_workers.kubeconfig_retrieve_instructions
  description = "Como obter o kubeconfig do cluster"
}

output "validation_command" {
  value       = module.k8s_workers.validation_command
  description = "Comando para validar o cluster"
}
`

type renderData struct {
	*config.AppConfig
	EnableSSM                bool
	EnableSSMVPCEndpoints    bool
	EnableDetailedMonitoring bool
	EndpointSubnetIDs        []string
}

func Generate(wsDir string, cfg *config.AppConfig) error {
	repoRoot, err := findRepoRoot()
	if err != nil {
		return fmt.Errorf("find repo root: %w", err)
	}

	srcModuleDir := filepath.Join(repoRoot, "terraform-modulesk8s-workers")
	dstModuleDir := filepath.Join(wsDir, "modules", "k8s-workers")
	if err := copyDir(srcModuleDir, dstModuleDir); err != nil {
		return fmt.Errorf("copy module dir: %w", err)
	}

	tpl, err := template.New("main.tf").Parse(mainTF)
	if err != nil {
		return fmt.Errorf("parse template: %w", err)
	}

	f, err := os.Create(filepath.Join(wsDir, "main.tf"))
	if err != nil {
		return fmt.Errorf("create main.tf: %w", err)
	}
	defer f.Close()

	endpointSubnetIDs := cfg.Infrastructure.SubnetIDs
	if len(endpointSubnetIDs) == 0 {
		endpointSubnetIDs = []string{cfg.Infrastructure.SubnetID}
	}

	data := renderData{
		AppConfig:                cfg,
		EnableSSM:                cfg.K8s.EnableSSM != nil && *cfg.K8s.EnableSSM,
		EnableSSMVPCEndpoints:    cfg.K8s.EnableSSMVPCEndpoints != nil && *cfg.K8s.EnableSSMVPCEndpoints,
		EnableDetailedMonitoring: cfg.K8s.EnableDetailedMonitoring != nil && *cfg.K8s.EnableDetailedMonitoring,
		EndpointSubnetIDs:        endpointSubnetIDs,
	}

	if err := tpl.Execute(f, data); err != nil {
		return fmt.Errorf("render template: %w", err)
	}

	if err := os.WriteFile(filepath.Join(wsDir, "outputs.tf"), []byte(outputsTF), 0o644); err != nil {
		return fmt.Errorf("create outputs.tf: %w", err)
	}

	return nil
}

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

	return "", fmt.Errorf("could not find go.mod starting from %q", cwd)
}

func copyDir(src, dst string) error {
	src = filepath.Clean(src)
	dst = filepath.Clean(dst)

	info, err := os.Stat(src)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("source is not directory: %s", src)
	}

	if err := os.MkdirAll(dst, info.Mode()); err != nil {
		return err
	}

	return filepath.WalkDir(src, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}

		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}

		target := filepath.Join(dst, rel)
		if d.IsDir() {
			info, err := d.Info()
			if err != nil {
				return err
			}
			return os.MkdirAll(target, info.Mode())
		}

		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()

		info, err := d.Info()
		if err != nil {
			return err
		}

		out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, info.Mode())
		if err != nil {
			return err
		}
		defer out.Close()

		if _, err := io.Copy(out, in); err != nil {
			return err
		}
		return nil
	})
}
