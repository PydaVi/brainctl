// Package generator gera o workspace Terragrunt a partir do AppConfig.
// A responsabilidade aqui é apenas materializar arquivos e inputs — a orquestração
// continua sendo do Terragrunt para evitar reimplementação de Terraform.
package generator

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"

	"github.com/PydaVi/brainctl/internal/config"
)

// terragruntHCLTemplate define o arquivo terragrunt.hcl gerado para cada workspace.
// tradeoff: usamos text/template (legibilidade e diffs simples) ao invés de hclwrite,
// aceitando menor validação formal de HCL em troca de um template direto e auditável.
const terragruntHCLTemplate = `# Gerado pelo brainctl — não editar manualmente
# Contrato: {{ .ContractPath }}

remote_state {
  backend = "s3"
  config = {
    bucket       = {{ quote .BackendBucket }}
    key          = {{ quote .BackendKey }}
    region       = {{ quote .BackendRegion }}
    encrypt      = true
  }
  disable_bucket_update = true
}

terraform {
  source = {{ quote .ModuleSource }}
}

inputs = {
  app_name    = {{ quote .App.Name }}
  environment = {{ quote .App.Environment }}
  region      = {{ quote .App.Region }}
  vpc_id      = {{ quote .Infrastructure.VpcID }}
  vpc_cidr    = {{ quote .Infrastructure.VpcCIDR }}
  subnet_id   = {{ quote .Infrastructure.SubnetID }}

  {{- if eq .WorkloadType "ec2-app" }}
  endpoint_subnet_ids = {{ hclStringList .Infrastructure.SubnetIDs }}
  allowed_egress_cidrs = {{ hclStringList .AllowedEgressCIDRs }}
  instance_type       = {{ quote .EC2.InstanceType }}
  app_instance_count  = {{ .LB.InstanceCount }}
  app_ami_id          = {{ quote .EC2.AMI }}
  app_user_data_mode  = {{ quote .EC2.UserDataMode }}
  app_user_data_base64 = {{ quote .AppUserDataB64 }}
  imds_v2_required    = {{ .EC2.IMDSv2Required }}
  allowed_rdp_cidr    = {{ quote .AllowedRDPCIDR }}

  enable_db           = {{ .DB.Enabled }}
  db_mode             = {{ quote .DB.Mode }}
  db_instance_type    = {{ quote .DB.InstanceType }}
  db_ami_id           = {{ quote .DB.AMI }}
  db_user_data_mode   = {{ quote .DB.UserDataMode }}
  db_user_data_base64 = {{ quote .DBUserDataB64 }}
  db_port             = {{ .DB.Port }}

  db_rds_instance_class        = {{ quote .DB.RDS.InstanceClass }}
  db_rds_engine                = {{ quote .DB.RDS.Engine }}
  db_rds_engine_version        = {{ quote .DB.RDS.EngineVersion }}
  db_rds_allocated_storage     = {{ .DB.RDS.AllocatedStorage }}
  db_rds_storage_type          = {{ quote .DB.RDS.StorageType }}
  db_rds_multi_az              = {{ .DB.RDS.MultiAZ }}
  db_rds_db_name               = {{ quote .DB.RDS.DBName }}
  db_rds_username              = {{ quote .DB.RDS.Username }}
  db_rds_password              = {{ quote .DB.RDS.Password }}
  db_rds_backup_retention_days = {{ .DB.RDS.BackupRetentionDays }}
  db_rds_publicly_accessible   = {{ .DB.RDS.PubliclyAccessible }}

  enable_lb        = {{ .LB.Enabled }}
  lb_scheme        = {{ quote .LB.Scheme }}
  lb_subnet_ids    = {{ hclStringList .LB.SubnetIDs }}
  lb_listener_port = {{ .LB.ListenerPort }}
  app_port         = {{ .LB.TargetPort }}
  lb_allowed_cidr  = {{ quote .AllowedLBCIDR }}

  enable_app_asg          = {{ .AppScaling.Enabled }}
  app_asg_subnet_ids      = {{ hclStringList .AppScaling.SubnetIDs }}
  app_asg_min_size        = {{ .AppScaling.MinSize }}
  app_asg_max_size        = {{ .AppScaling.MaxSize }}
  app_asg_desired_capacity = {{ .AppScaling.DesiredCapacity }}
  app_asg_cpu_target      = {{ .AppScaling.CPUTarget }}

  enable_observability   = {{ .ObservabilityEnabled }}
  enable_ssm_endpoints   = {{ .ObservabilityEnableSSMEndpoints }}
  enable_ssm_private_dns = {{ .ObservabilityEnableSSMPrivateDNS }}
  cpu_high_threshold     = {{ .Observability.CPUHighThreshold }}
  alert_email            = {{ quote .Observability.AlertEmail }}
  cloudwatch_log_kms_key_id = {{ quote .Observability.LogKMSKeyID }}

  enable_recovery_mode                  = {{ .Recovery.Enabled }}
  recovery_snapshot_time_utc            = {{ quote .Recovery.SnapshotTimeUTC }}
  recovery_retention_days               = {{ .Recovery.RetentionDays }}
  recovery_backup_app                   = {{ .RecoveryBackupApp }}
  recovery_backup_db                    = {{ .RecoveryBackupDB }}
  recovery_enable_runbooks              = {{ .RecoveryEnableRunbooks }}
  recovery_drill_enabled                = {{ .Recovery.Drill.Enabled }}
  recovery_drill_schedule_expression    = {{ quote .Recovery.Drill.ScheduleExpression }}
  recovery_drill_register_to_target_group = {{ .RecoveryDrillRegisterToTargetGroup }}

  app_extra_ingress_rules = {{ hclIngressRules .RuntimeOverrides.AppExtraIngress }}
  db_extra_ingress_rules  = {{ hclIngressRules .RuntimeOverrides.DBExtraIngress }}
  alb_extra_ingress_rules = {{ hclIngressRules .RuntimeOverrides.ALBExtraIngress }}
  {{- end }}

  {{- if eq .WorkloadType "k8s-workers" }}
  endpoint_subnet_ids       = {{ hclStringList .Infrastructure.SubnetIDs }}
  allowed_egress_cidrs       = {{ hclStringList .AllowedEgressCIDRs }}
  control_plane_ami         = {{ quote .K8s.ControlPlaneAMI }}
  worker_ami                = {{ quote .K8s.WorkerAMI }}
  control_plane_type        = {{ quote .K8s.ControlPlaneInstanceType }}
  worker_type               = {{ quote .K8s.WorkerInstanceType }}
  worker_count              = {{ .K8s.WorkerCount }}
  kubernetes_version        = {{ quote .K8s.KubernetesVersion }}
  pod_cidr                  = {{ quote .K8s.PodCIDR }}
  key_name                  = {{ quote .K8s.KeyName }}
  admin_cidr                = {{ quote .K8s.AdminCIDR }}
  enable_nat_gateway        = {{ boolValue .K8s.EnableNatGateway }}
  public_subnet_id          = {{ quote .K8s.PublicSubnetID }}
  public_subnet_cidr        = {{ quote .K8s.PublicSubnetCIDR }}
  internet_gateway_id       = {{ quote .K8s.InternetGatewayID }}
  private_route_table_id    = {{ quote .K8s.PrivateRouteTableID }}
  enable_ssm                = {{ boolValue .K8s.EnableSSM }}
  enable_detailed_monitoring = {{ boolValue .K8s.EnableDetailedMonitoring }}
  enable_ssm_vpc_endpoints  = {{ boolValue .K8s.EnableSSMVPCEndpoints }}
  {{- end }}
}
`

// WorkspaceDir define um caminho determinístico para o workspace por app/ambiente.
// A escolha evita múltiplos workspaces por engano e facilita limpeza automatizada.
func WorkspaceDir(cfg *config.AppConfig) string {
	name := fmt.Sprintf("%s-%s", cfg.App.Name, cfg.App.Environment)
	return filepath.Join(".brainctl-workspace", name)
}

// PrepareWorkspace cria o diretório e gera o terragrunt.hcl com inputs do contrato.
// Mantemos essa função aqui para centralizar o fluxo de geração e reduzir acoplamento
// da CLI com detalhes de filesystem e template.
func PrepareWorkspace(cfg *config.AppConfig, contractPath string) (string, error) {
	wsDir := WorkspaceDir(cfg)
	if err := os.MkdirAll(wsDir, 0o755); err != nil {
		return "", fmt.Errorf("create workspace dir %s: %w", wsDir, err)
	}
	if err := Generate(wsDir, cfg, contractPath); err != nil {
		return "", err
	}
	return wsDir, nil
}

// Generate cria o terragrunt.hcl e prepara o módulo alvo dentro do workspace.
// A geração depende do AppConfig validado para manter defaults consistentes.
func Generate(wsDir string, cfg *config.AppConfig, contractPath string) error {
	absContract, err := filepath.Abs(contractPath)
	if err != nil {
		return fmt.Errorf("resolve contract path: %w", err)
	}
	repoRoot, err := findRepoRoot(filepath.Dir(absContract))
	if err != nil {
		return fmt.Errorf("resolve repo root: %w", err)
	}
	moduleRoot := filepath.Join(repoRoot, "modules")
	moduleTarget := filepath.Join(moduleRoot, cfg.Workload.Type)
	moduleLink := filepath.Join(wsDir, "modules", cfg.Workload.Type)

	if err := os.MkdirAll(filepath.Dir(moduleLink), 0o755); err != nil {
		return fmt.Errorf("create workspace modules dir: %w", err)
	}
	if err := ensureModuleLink(moduleLink, moduleTarget); err != nil {
		return fmt.Errorf("prepare module link: %w", err)
	}

	rendered, err := renderTerragruntHCL(cfg, absContract, filepath.ToSlash(filepath.Join("modules", cfg.Workload.Type)))
	if err != nil {
		return fmt.Errorf("render terragrunt.hcl: %w", err)
	}
	outPath := filepath.Join(wsDir, "terragrunt.hcl")
	if err := os.WriteFile(outPath, rendered, 0o644); err != nil {
		return fmt.Errorf("write terragrunt.hcl: %w", err)
	}
	return nil
}

// renderTerragruntHCL aplica o template com os valores já normalizados.
// A separação mantém a lógica de template isolada do filesystem.
func renderTerragruntHCL(cfg *config.AppConfig, contractPath string, moduleSource string) ([]byte, error) {
	tpl, err := template.New("terragrunt.hcl").Funcs(template.FuncMap{
		"quote":         strconv.Quote,
		"hclStringList": hclStringList,
		"hclIngressRules": func(rules []config.IngressRule) string {
			return hclIngressRules(rules)
		},
		"boolValue": boolValue,
	}).Parse(terragruntHCLTemplate)
	if err != nil {
		return nil, fmt.Errorf("parse template: %w", err)
	}

	data := terragruntTemplateData{
		AppConfig:                          cfg,
		ContractPath:                       filepath.ToSlash(contractPath),
		BackendBucket:                      cfg.Terraform.Backend.Bucket,
		BackendKey:                         backendKey(cfg),
		BackendRegion:                      cfg.Terraform.Backend.Region,
		ModuleSource:                       moduleSource,
		WorkloadType:                       cfg.Workload.Type,
		AppUserDataB64:                     base64.StdEncoding.EncodeToString([]byte(cfg.EC2.UserData)),
		DBUserDataB64:                      base64.StdEncoding.EncodeToString([]byte(cfg.DB.UserData)),
		ObservabilityEnabled:               derefBool(cfg.Observability.Enabled),
		ObservabilityEnableSSMEndpoints:    derefBool(cfg.Observability.EnableSSMEndpoints),
		ObservabilityEnableSSMPrivateDNS:   derefBool(cfg.Observability.EnableSSMPrivateDNS),
		RecoveryBackupApp:                  derefBool(cfg.Recovery.BackupApp),
		RecoveryBackupDB:                   derefBool(cfg.Recovery.BackupDB),
		RecoveryEnableRunbooks:             derefBool(cfg.Recovery.EnableRunbooks),
		RecoveryDrillRegisterToTargetGroup: derefBool(cfg.Recovery.Drill.RegisterToTargetGroup),
		AllowedRDPCIDR:                     effectiveCIDR(cfg.EC2.AllowedRDPCIDR, cfg.Infrastructure.VpcCIDR),
		AllowedLBCIDR:                      effectiveCIDR(cfg.LB.AllowedCIDR, cfg.Infrastructure.VpcCIDR),
		AllowedEgressCIDRs:                 effectiveEgressCIDRs(cfg.Infrastructure.AllowedEgressCIDRs, cfg.Infrastructure.VpcCIDR),
	}

	var buf bytes.Buffer
	if err := tpl.Execute(&buf, data); err != nil {
		return nil, fmt.Errorf("execute template: %w", err)
	}
	return buf.Bytes(), nil
}

// terragruntTemplateData expõe campos calculados para evitar lógica complexa no template.
// Essa abordagem mantém o HCL gerado legível e reduz branching no template.
type terragruntTemplateData struct {
	*config.AppConfig
	ContractPath                       string
	BackendBucket                      string
	BackendKey                         string
	BackendRegion                      string
	ModuleSource                       string
	WorkloadType                       string
	AppUserDataB64                     string
	DBUserDataB64                      string
	ObservabilityEnabled               bool
	ObservabilityEnableSSMEndpoints    bool
	ObservabilityEnableSSMPrivateDNS   bool
	RecoveryBackupApp                  bool
	RecoveryBackupDB                   bool
	RecoveryEnableRunbooks             bool
	RecoveryDrillRegisterToTargetGroup bool
	AllowedRDPCIDR                     string
	AllowedLBCIDR                      string
	AllowedEgressCIDRs                 []string
}

// effectiveCIDR aplica fallback explícito para manter o template simples.
func effectiveCIDR(primary, fallback string) string {
	if strings.TrimSpace(primary) != "" {
		return primary
	}
	return fallback
}

// effectiveEgressCIDRs garante que exista ao menos um CIDR de egress permitido.
func effectiveEgressCIDRs(cidrs []string, fallback string) []string {
	if len(cidrs) > 0 {
		return cidrs
	}
	if strings.TrimSpace(fallback) == "" {
		return nil
	}
	return []string{fallback}
}

// backendKey materializa o padrão de key com prefixo e app/ambiente.
// Mantemos isso centralizado para que alterações futuras não dispersem a regra.
func backendKey(cfg *config.AppConfig) string {
	prefix := strings.Trim(cfg.Terraform.Backend.KeyPrefix, "/")
	base := fmt.Sprintf("%s/%s/terraform.tfstate", cfg.App.Name, cfg.App.Environment)
	if prefix == "" {
		return base
	}
	return fmt.Sprintf("%s/%s", prefix, base)
}

// findRepoRoot sobe a árvore a partir do contrato até encontrar o diretório do repo.
// Isso evita depender do cwd e facilita execução da CLI fora do root.
func findRepoRoot(startDir string) (string, error) {
	dir := startDir
	for {
		if dir == "" || dir == "." {
			break
		}
		if fileExists(filepath.Join(dir, "go.mod")) && fileExists(filepath.Join(dir, "modules")) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("repo root not found starting at %s", startDir)
}

// ensureModuleLink aponta o módulo do workspace para o módulo real do repo.
// Preferimos symlink por ser rápido; se indisponível, copiamos o diretório.
func ensureModuleLink(linkPath, target string) error {
	if info, err := os.Lstat(linkPath); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			current, err := os.Readlink(linkPath)
			if err != nil {
				return fmt.Errorf("readlink %s: %w", linkPath, err)
			}
			if current == target {
				return nil
			}
		}
		return fmt.Errorf("module path already exists and is not the expected symlink: %s", linkPath)
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("stat module link %s: %w", linkPath, err)
	}

	if err := os.Symlink(target, linkPath); err == nil {
		return nil
	}
	return copyDir(target, linkPath)
}

// copyDir replica o conteúdo do módulo quando symlink não é suportado.
// Esta alternativa é mais lenta, mas garante que o workspace funcione.
func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		return copyFile(path, target, info.Mode())
	})
}

// copyFile mantém permissão de origem para evitar mudanças sutis no módulo.
func copyFile(src, dst string, mode fs.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return nil
}

// hclStringList formata listas de strings como literal HCL.
// Fazer isso manualmente evita depender de libs externas nesta camada.
func hclStringList(values []string) string {
	if len(values) == 0 {
		return "[]"
	}
	quoted := make([]string, 0, len(values))
	for _, v := range values {
		quoted = append(quoted, strconv.Quote(v))
	}
	return fmt.Sprintf("[%s]", strings.Join(quoted, ", "))
}

// hclIngressRules serializa ingress rules como literal HCL.
// Optamos por strings para evitar reimplementação de HCL AST.
func hclIngressRules(rules []config.IngressRule) string {
	if len(rules) == 0 {
		return "[]"
	}
	entries := make([]string, 0, len(rules))
	for _, rule := range rules {
		entry := fmt.Sprintf(
			`{ description = %s, from_port = %d, to_port = %d, protocol = %s, cidr_blocks = %s }`,
			strconv.Quote(rule.Description),
			rule.FromPort,
			rule.ToPort,
			strconv.Quote(rule.Protocol),
			hclStringList(rule.CIDRBlocks),
		)
		entries = append(entries, entry)
	}
	return fmt.Sprintf("[%s]", strings.Join(entries, ", "))
}

// boolValue converte ponteiros em bools estáveis no template.
// Escolhemos default false para evitar nil deref mesmo com config inválida.
func boolValue(v *bool) bool {
	if v == nil {
		return false
	}
	return *v
}

// derefBool aplica o mesmo comportamento para campos obrigatórios já validados.
func derefBool(v *bool) bool {
	if v == nil {
		return false
	}
	return *v
}

// fileExists reduz a verbosidade das checagens de presença no filesystem.
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
