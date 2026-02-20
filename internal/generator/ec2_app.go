package generator

import (
	"encoding/base64"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/PydaVi/brainctl/internal/config"
)

// mainTF é o template do root module gerado por workload.
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

module "app" {
  source = "./modules/ec2-app"

  name        = "{{ .App.Name }}"
  environment = "{{ .App.Environment }}"
  region      = "{{ .App.Region }}"

  vpc_id    = "{{ .Infrastructure.VpcID }}"
  subnet_id = "{{ .Infrastructure.SubnetID }}"
  endpoint_subnet_ids = [{{- range $i, $s := .Infrastructure.SubnetIDs -}}{{- if $i }}, {{ end }}"{{ $s }}"{{- end -}}]

  instance_type       = "{{ .EC2.InstanceType }}"
  app_instance_count  = {{ .LB.InstanceCount }}
  app_ami_id          = "{{ .EC2.AMI }}"
  app_user_data_mode  = "{{ .EC2.UserDataMode }}"
  app_user_data_base64 = "{{ .AppUserDataB64 }}"
  imds_v2_required    = {{ .EC2.IMDSv2Required }}
  allowed_rdp_cidr    = "0.0.0.0/0"

  enable_db           = {{ .DB.Enabled }}
  db_mode             = "{{ .DB.Mode }}"
  db_instance_type    = "{{ .DB.InstanceType }}"
  db_ami_id           = "{{ .DB.AMI }}"
  db_user_data_mode   = "{{ .DB.UserDataMode }}"
  db_user_data_base64 = "{{ .DBUserDataB64 }}"
  db_port             = {{ .DB.Port }}

  db_rds_instance_class        = "{{ .DB.RDS.InstanceClass }}"
  db_rds_engine                = "{{ .DB.RDS.Engine }}"
  db_rds_engine_version        = "{{ .DB.RDS.EngineVersion }}"
  db_rds_allocated_storage     = {{ .DB.RDS.AllocatedStorage }}
  db_rds_storage_type          = "{{ .DB.RDS.StorageType }}"
  db_rds_multi_az              = {{ .DB.RDS.MultiAZ }}
  db_rds_db_name               = "{{ .DB.RDS.DBName }}"
  db_rds_username              = "{{ .DB.RDS.Username }}"
  db_rds_password              = "{{ .DB.RDS.Password }}"
  db_rds_backup_retention_days = {{ .DB.RDS.BackupRetentionDays }}
  db_rds_publicly_accessible   = {{ .DB.RDS.PubliclyAccessible }}

  enable_lb        = {{ .LB.Enabled }}
  lb_scheme        = "{{ .LB.Scheme }}"
  lb_subnet_ids    = [{{- range $i, $s := .LB.SubnetIDs -}}{{- if $i }}, {{ end }}"{{ $s }}"{{- end -}}]

  lb_listener_port = {{ .LB.ListenerPort }}
  app_port         = {{ .LB.TargetPort }}
  lb_allowed_cidr  = "{{ .LB.AllowedCIDR }}"

  enable_app_asg         = {{ .AppScaling.Enabled }}
  app_asg_subnet_ids     = [{{- range $i, $s := .AppScaling.SubnetIDs -}}{{- if $i }}, {{ end }}"{{ $s }}"{{- end -}}]
  app_asg_min_size       = {{ .AppScaling.MinSize }}
  app_asg_max_size       = {{ .AppScaling.MaxSize }}
  app_asg_desired_capacity = {{ .AppScaling.DesiredCapacity }}
  app_asg_cpu_target     = {{ .AppScaling.CPUTarget }}

  enable_observability = {{ .ObservabilityEnabled }}
  cpu_high_threshold   = {{ .Observability.CPUHighThreshold }}
  alert_email          = "{{ .Observability.AlertEmail }}"

  enable_recovery_mode         = {{ .Recovery.Enabled }}
  recovery_snapshot_time_utc   = "{{ .Recovery.SnapshotTimeUTC }}"
  recovery_retention_days      = {{ .Recovery.RetentionDays }}
  recovery_backup_app          = {{ .RecoveryBackupApp }}
  recovery_backup_db           = {{ .RecoveryBackupDB }}
  recovery_enable_runbooks     = {{ .RecoveryEnableRunbooks }}
  recovery_drill_enabled       = {{ .Recovery.Drill.Enabled }}
  recovery_drill_schedule_expression = "{{ .Recovery.Drill.ScheduleExpression }}"
  recovery_drill_register_to_target_group = {{ .RecoveryDrillRegisterToTargetGroup }}

  app_extra_ingress_rules = [{{ .AppExtraIngressHCL }}]
  db_extra_ingress_rules  = [{{ .DBExtraIngressHCL }}]
  alb_extra_ingress_rules = [{{ .ALBExtraIngressHCL }}]
}
`

// outputsTF expõe, no root module, os outputs principais para status/output.
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

output "app_instance_ids" {
  value       = module.app.app_instance_ids
  description = "APP EC2 instance ids when ASG is disabled"
}

output "app_private_ips" {
  value       = module.app.app_private_ips
  description = "APP EC2 private ips when ASG is disabled"
}

output "app_asg_name" {
  value       = module.app.app_asg_name
  description = "App ASG name"
}

output "app_asg_min_size" {
  value       = module.app.app_asg_min_size
  description = "App ASG min size"
}

output "app_asg_max_size" {
  value       = module.app.app_asg_max_size
  description = "App ASG max size"
}

output "app_asg_desired_capacity" {
  value       = module.app.app_asg_desired_capacity
  description = "App ASG desired capacity"
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
  description = "DB instance id (EC2 mode)"
}

output "db_private_ip" {
  value       = module.app.db_private_ip
  description = "DB private ip (EC2 mode)"
}

output "db_security_group_id" {
  value       = module.app.db_security_group_id
  description = "DB SG id"
}

output "db_security_group_name" {
  value       = module.app.db_security_group_name
  description = "DB SG name"
}

output "db_rds_instance_id" {
  value       = module.app.db_rds_instance_id
  description = "DB instance id (RDS mode)"
}

output "db_rds_endpoint" {
  value       = module.app.db_rds_endpoint
  description = "RDS endpoint"
}

output "db_rds_port" {
  value       = module.app.db_rds_port
  description = "RDS port"
}

output "alb_dns_name" {
  value       = module.app.alb_dns_name
  description = "ALB DNS name"
}

output "alb_arn" {
  value       = module.app.alb_arn
  description = "ALB ARN"
}

output "alb_target_group_arn" {
  value       = module.app.alb_target_group_arn
  description = "ALB Target Group ARN"
}

output "observability_app_dashboard_name" {
  value       = module.app.observability_app_dashboard_name
  description = "CloudWatch APP dashboard name"
}

output "observability_app_dashboard_url" {
  value       = module.app.observability_app_dashboard_url
  description = "CloudWatch APP dashboard URL"
}

output "observability_db_dashboard_name" {
  value       = module.app.observability_db_dashboard_name
  description = "CloudWatch DB dashboard name"
}

output "observability_db_dashboard_url" {
  value       = module.app.observability_db_dashboard_url
  description = "CloudWatch DB dashboard URL"
}

output "observability_sre_dashboard_name" {
  value       = module.app.observability_sre_dashboard_name
  description = "CloudWatch SRE dashboard name"
}

output "observability_sre_dashboard_url" {
  value       = module.app.observability_sre_dashboard_url
  description = "CloudWatch SRE dashboard URL"
}

output "observability_executive_dashboard_name" {
  value       = module.app.observability_executive_dashboard_name
  description = "CloudWatch Executive dashboard name"
}

output "observability_executive_dashboard_url" {
  value       = module.app.observability_executive_dashboard_url
  description = "CloudWatch Executive dashboard URL"
}

output "observability_infra_dashboard_name" {
  value       = module.app.observability_infra_dashboard_name
  description = "CloudWatch Infra dashboard name"
}

output "observability_infra_dashboard_url" {
  value       = module.app.observability_infra_dashboard_url
  description = "CloudWatch Infra dashboard URL"
}

output "observability_alarm_names" {
  value       = module.app.observability_alarm_names
  description = "CloudWatch alarm names"
}

output "observability_sns_topic_arn" {
  value       = module.app.observability_sns_topic_arn
  description = "SNS topic ARN used for alerts"
}

output "observability_sns_topic_sev1_arn" {
  value       = module.app.observability_sns_topic_sev1_arn
  description = "SNS topic ARN used for Sev1 alerts"
}

output "observability_sns_topic_sev2_arn" {
  value       = module.app.observability_sns_topic_sev2_arn
  description = "SNS topic ARN used for Sev2 alerts"
}

output "observability_sns_topic_sev3_arn" {
  value       = module.app.observability_sns_topic_sev3_arn
  description = "SNS topic ARN used for Sev3 alerts"
}

output "observability_alert_email" {
  value       = module.app.observability_alert_email
  description = "Configured alert email"
}

output "recovery_enabled" {
  value       = module.app.recovery_enabled
  description = "Recovery mode enabled"
}

output "recovery_snapshot_time_utc" {
  value       = module.app.recovery_snapshot_time_utc
  description = "Daily snapshot time (UTC)"
}

output "recovery_retention_days" {
  value       = module.app.recovery_retention_days
  description = "Recovery retention in days"
}

output "recovery_app_policy_id" {
  value       = module.app.recovery_app_policy_id
  description = "DLM policy id for APP snapshots"
}

output "recovery_db_policy_id" {
  value       = module.app.recovery_db_policy_id
  description = "DLM policy id for DB snapshots"
}

output "recovery_app_runbook_name" {
  value       = module.app.recovery_app_runbook_name
  description = "Automation runbook name for APP recovery"
}

output "recovery_db_runbook_name" {
  value       = module.app.recovery_db_runbook_name
  description = "Automation runbook name for DB recovery"
}

output "recovery_drill_schedule_name" {
  value       = module.app.recovery_drill_schedule_name
  description = "EventBridge Scheduler name for monthly DR drill"
}
`

// renderData injeta dados auxiliares no template (ex.: bool defaultizado).
type renderData struct {
	*config.AppConfig
	ObservabilityEnabled   bool
	RecoveryBackupApp      bool
	RecoveryBackupDB       bool
	RecoveryEnableRunbooks bool
	AppUserDataB64         string
	DBUserDataB64          string
	AppExtraIngressHCL     string
	DBExtraIngressHCL      string
	ALBExtraIngressHCL     string
}

// GenerateEC2App monta workspace Terraform completo para a aplicação.
func GenerateEC2App(wsDir string, cfg *config.AppConfig) error {
	repoRoot, err := findRepoRoot()
	if err != nil {
		return fmt.Errorf("find repo root: %w", err)
	}

	srcModuleDir := filepath.Join(repoRoot, "terraform-modulesec2-app")
	dstModuleDir := filepath.Join(wsDir, "modules", "ec2-app")

	if err := copyDir(srcModuleDir, dstModuleDir); err != nil {
		return fmt.Errorf("copy module dir: %w", err)
	}

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

	data := renderData{
		AppConfig:              cfg,
		ObservabilityEnabled:   cfg.Observability.Enabled != nil && *cfg.Observability.Enabled,
		RecoveryBackupApp:      cfg.Recovery.BackupApp != nil && *cfg.Recovery.BackupApp,
		RecoveryBackupDB:       cfg.Recovery.BackupDB != nil && *cfg.Recovery.BackupDB,
		RecoveryEnableRunbooks: cfg.Recovery.EnableRunbooks != nil && *cfg.Recovery.EnableRunbooks,
		AppUserDataB64:         encodeBase64(cfg.EC2.UserData),
		DBUserDataB64:          encodeBase64(cfg.DB.UserData),
		AppExtraIngressHCL:     buildIngressRulesHCL(cfg.RuntimeOverrides.AppExtraIngress),
		DBExtraIngressHCL:      buildIngressRulesHCL(cfg.RuntimeOverrides.DBExtraIngress),
		ALBExtraIngressHCL:     buildIngressRulesHCL(cfg.RuntimeOverrides.ALBExtraIngress),
	}
	if err := tpl.Execute(f, data); err != nil {
		return fmt.Errorf("render template: %w", err)
	}

	outPath := filepath.Join(wsDir, "outputs.tf")
	if err := os.WriteFile(outPath, []byte(outputsTF), 0o644); err != nil {
		return fmt.Errorf("create outputs.tf: %w", err)
	}

	return nil
}

func buildIngressRulesHCL(rules []config.IngressRule) string {
	if len(rules) == 0 {
		return ""
	}
	parts := make([]string, 0, len(rules))
	for _, r := range rules {
		cidrs := make([]string, 0, len(r.CIDRBlocks))
		for _, c := range r.CIDRBlocks {
			cidrs = append(cidrs, fmt.Sprintf("\"%s\"", c))
		}
		parts = append(parts, fmt.Sprintf("{ description = %q, from_port = %d, to_port = %d, protocol = %q, cidr_blocks = [%s] }", r.Description, r.FromPort, r.ToPort, r.Protocol, strings.Join(cidrs, ", ")))
	}
	return strings.Join(parts, ", ")
}

func encodeBase64(v string) string {
	if v == "" {
		return ""
	}
	return base64.StdEncoding.EncodeToString([]byte(v))
}

// findRepoRoot sobe diretórios até localizar go.mod.
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

// copyDir replica o módulo Terraform para dentro do workspace.
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

		if d.Type()&os.ModeSymlink != 0 {
			return nil
		}

		return copyFile(path, targetPath)
	})
}

// copyFile copia arquivo a arquivo preservando estrutura de destino.
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
