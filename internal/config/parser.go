package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// AppConfig representa o contrato declarativo consumido pelo brainctl.
// A ideia é manter o YAML simples para o usuário, enquanto a lógica de
// orquestração é aplicada pelo Go + módulos Terraform.
type AppConfig struct {
	Workload WorkloadConfig `yaml:"workload"`

	App struct {
		Name        string `yaml:"name"`
		Environment string `yaml:"environment"`
		Region      string `yaml:"region"`
	} `yaml:"app"`

	Infrastructure struct {
		VpcID     string   `yaml:"vpc_id"`
		SubnetID  string   `yaml:"subnet_id"`
		SubnetIDs []string `yaml:"subnet_ids"`
	} `yaml:"infrastructure"`

	EC2 struct {
		InstanceType   string `yaml:"instance_type"`
		OS             string `yaml:"os"`
		AMI            string `yaml:"ami"`
		UserData       string `yaml:"user_data"`
		UserDataMode   string `yaml:"user_data_mode"`
		IMDSv2Required bool   `yaml:"imds_v2_required"`
	} `yaml:"ec2"`

	DB            DBConfig            `yaml:"db"`
	LB            LBConfig            `yaml:"lb"`
	AppScaling    AppScalingConfig    `yaml:"app_scaling"`
	Observability ObservabilityConfig `yaml:"observability"`
	Recovery      RecoveryConfig      `yaml:"recovery"`

	K8s K8sWorkersConfig `yaml:"k8s"`

	// RuntimeOverrides são alterações aplicadas por overrides.yaml (não fazem parte do contrato base).
	RuntimeOverrides RuntimeOverrides `yaml:"-"`
}

// WorkloadConfig identifica qual blueprint deve ser usado para gerar a stack.
type WorkloadConfig struct {
	Type    string `yaml:"type"`
	Version string `yaml:"version"`
}

// K8sWorkersConfig define parâmetros do blueprint self-managed kubeadm em EC2.
type K8sWorkersConfig struct {
	ControlPlaneInstanceType string `yaml:"control_plane_instance_type"`
	WorkerInstanceType       string `yaml:"worker_instance_type"`
	ControlPlaneAMI          string `yaml:"control_plane_ami"`
	WorkerAMI                string `yaml:"worker_ami"`
	WorkerCount              int    `yaml:"worker_count"`
	KubernetesVersion        string `yaml:"kubernetes_version"`
	PodCIDR                  string `yaml:"pod_cidr"`
	KeyName                  string `yaml:"key_name"`
	AdminCIDR                string `yaml:"admin_cidr"`
	EnableSSM                *bool  `yaml:"enable_ssm"`
	EnableDetailedMonitoring *bool  `yaml:"enable_detailed_monitoring"`
}

// DBConfig define o bloco opcional de banco.
type DBConfig struct {
	Enabled      bool   `yaml:"enabled"`
	Mode         string `yaml:"mode"`
	InstanceType string `yaml:"instance_type"`
	Port         int    `yaml:"port"`
	OS           string `yaml:"os"`
	AMI          string `yaml:"ami"`
	UserData     string `yaml:"user_data"`
	UserDataMode string `yaml:"user_data_mode"`
	RDS          struct {
		InstanceClass       string `yaml:"instance_class"`
		Engine              string `yaml:"engine"`
		EngineVersion       string `yaml:"engine_version"`
		AllocatedStorage    int    `yaml:"allocated_storage"`
		StorageType         string `yaml:"storage_type"`
		MultiAZ             bool   `yaml:"multi_az"`
		DBName              string `yaml:"db_name"`
		Username            string `yaml:"username"`
		Password            string `yaml:"password"`
		BackupRetentionDays int    `yaml:"backup_retention_days"`
		PubliclyAccessible  bool   `yaml:"publicly_accessible"`
	} `yaml:"rds"`
}

// LBConfig define parâmetros de load balancer.
type LBConfig struct {
	Enabled       bool     `yaml:"enabled"`
	Scheme        string   `yaml:"scheme"`
	SubnetIDs     []string `yaml:"subnet_ids"`
	ListenerPort  int      `yaml:"listener_port"`
	TargetPort    int      `yaml:"target_port"`
	AllowedCIDR   string   `yaml:"allowed_cidr"`
	InstanceCount int      `yaml:"instance_count"`
}

type AppScalingConfig struct {
	Enabled         bool     `yaml:"enabled"`
	SubnetIDs       []string `yaml:"subnet_ids"`
	MinSize         int      `yaml:"min_size"`
	MaxSize         int      `yaml:"max_size"`
	DesiredCapacity int      `yaml:"desired_capacity"`
	CPUTarget       float64  `yaml:"cpu_target"`
}

// ObservabilityConfig controla dashboards, alarmes e SNS.
type ObservabilityConfig struct {
	Enabled             *bool  `yaml:"enabled"`
	CPUHighThreshold    int    `yaml:"cpu_high_threshold"`
	AlertEmail          string `yaml:"alert_email"`
	EnableSSMEndpoints  *bool  `yaml:"enable_ssm_endpoints"`
	EnableSSMPrivateDNS *bool  `yaml:"enable_ssm_private_dns"`
}

// RecoveryConfig define snapshots automáticos e runbooks de recuperação.
type RecoveryConfig struct {
	Enabled         bool                `yaml:"enabled"`
	SnapshotTimeUTC string              `yaml:"snapshot_time_utc"`
	RetentionDays   int                 `yaml:"retention_days"`
	BackupApp       *bool               `yaml:"backup_app"`
	BackupDB        *bool               `yaml:"backup_db"`
	EnableRunbooks  *bool               `yaml:"enable_runbooks"`
	Drill           RecoveryDrillConfig `yaml:"drill"`
}

type RecoveryDrillConfig struct {
	Enabled               bool   `yaml:"enabled"`
	ScheduleExpression    string `yaml:"schedule_expression"`
	RegisterToTargetGroup *bool  `yaml:"register_to_target_group"`
}

type RuntimeOverrides struct {
	AppExtraIngress []IngressRule
	DBExtraIngress  []IngressRule
	ALBExtraIngress []IngressRule
}

type IngressRule struct {
	Description string   `yaml:"description"`
	FromPort    int      `yaml:"from_port"`
	ToPort      int      `yaml:"to_port"`
	Protocol    string   `yaml:"protocol"`
	CIDRBlocks  []string `yaml:"cidr_blocks"`
}

type OverrideFile struct {
	Overrides []OverrideOp `yaml:"overrides"`
}

type OverrideOp struct {
	Op    string `yaml:"op"`
	Path  string `yaml:"path"`
	Value any    `yaml:"value"`
}

// LoadConfig lê e desserializa o YAML informado pelo usuário.
func LoadConfig(path string) (*AppConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var cfg AppConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

// ApplyOverridesFile aplica customizações extras controladas por whitelist.
func ApplyOverridesFile(cfg *AppConfig, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	var f OverrideFile
	if err := yaml.Unmarshal(data, &f); err != nil {
		return fmt.Errorf("invalid overrides file: %w", err)
	}

	for i, o := range f.Overrides {
		if err := applyOverride(cfg, o); err != nil {
			return fmt.Errorf("override[%d] (%s %s): %w", i, o.Op, o.Path, err)
		}
	}
	return nil
}

func applyOverride(cfg *AppConfig, o OverrideOp) error {
	switch o.Path {
	case "security_groups.app.ingress":
		r, err := parseAppendIngressRule(o, "security_groups.app.ingress")
		if err != nil {
			return err
		}
		cfg.RuntimeOverrides.AppExtraIngress = append(cfg.RuntimeOverrides.AppExtraIngress, r)
		return nil
	case "security_groups.db.ingress":
		r, err := parseAppendIngressRule(o, "security_groups.db.ingress")
		if err != nil {
			return err
		}
		cfg.RuntimeOverrides.DBExtraIngress = append(cfg.RuntimeOverrides.DBExtraIngress, r)
		return nil
	case "security_groups.alb.ingress":
		r, err := parseAppendIngressRule(o, "security_groups.alb.ingress")
		if err != nil {
			return err
		}
		cfg.RuntimeOverrides.ALBExtraIngress = append(cfg.RuntimeOverrides.ALBExtraIngress, r)
		return nil
	default:
		return fmt.Errorf("path not allowed")
	}
}

func parseAppendIngressRule(o OverrideOp, path string) (IngressRule, error) {
	if o.Op != "append" {
		return IngressRule{}, fmt.Errorf("only 'append' is allowed for %s", path)
	}
	raw, err := yaml.Marshal(o.Value)
	if err != nil {
		return IngressRule{}, err
	}

	var r IngressRule
	if err := yaml.Unmarshal(raw, &r); err != nil {
		return IngressRule{}, fmt.Errorf("invalid ingress rule: %w", err)
	}
	if r.Protocol == "" {
		r.Protocol = "tcp"
	}
	if len(r.CIDRBlocks) == 0 {
		return IngressRule{}, fmt.Errorf("cidr_blocks is required")
	}
	return r, nil
}

func validateUserDataMode(mode string) bool {
	return mode == "default" || mode == "custom" || mode == "merge"
}

// ResolveUserDataFiles permite apontar user_data para arquivos, mantendo app.yaml enxuto.
// Suporta:
//   - file://caminho/relativo/ou/absoluto.ps1
//   - caminho direto (relativo/absoluto) quando o arquivo existe
func ResolveUserDataFiles(cfg *AppConfig, stackDir string) error {
	appResolved, err := resolveUserDataValue(cfg.EC2.UserData, stackDir)
	if err != nil {
		return fmt.Errorf("ec2.user_data: %w", err)
	}
	dbResolved, err := resolveUserDataValue(cfg.DB.UserData, stackDir)
	if err != nil {
		return fmt.Errorf("db.user_data: %w", err)
	}

	cfg.EC2.UserData = appResolved
	cfg.DB.UserData = dbResolved
	return nil
}

func resolveUserDataValue(raw, stackDir string) (string, error) {
	v := strings.TrimSpace(raw)
	if v == "" {
		return "", nil
	}

	if strings.Contains(v, "\n") {
		return raw, nil
	}

	fromFilePrefix := strings.HasPrefix(v, "file://")
	candidate := strings.TrimPrefix(v, "file://")
	if !filepath.IsAbs(candidate) {
		candidate = filepath.Join(stackDir, candidate)
	}

	info, err := os.Stat(candidate)
	if err != nil {
		if fromFilePrefix {
			return "", fmt.Errorf("file not found: %s", candidate)
		}
		return raw, nil
	}
	if info.IsDir() {
		return "", fmt.Errorf("path points to directory, expected file: %s", candidate)
	}

	content, err := os.ReadFile(candidate)
	if err != nil {
		return "", fmt.Errorf("read file %s: %w", candidate, err)
	}
	return string(content), nil
}

// Validate aplica regras e defaults do contrato declarativo.
func (c *AppConfig) Validate() error {
	if c.Workload.Type == "" {
		c.Workload.Type = "ec2-app"
	}
	if c.Workload.Version == "" {
		c.Workload.Version = "v1"
	}
	if c.Workload.Type != "ec2-app" && c.Workload.Type != "k8s-workers" {
		return fmt.Errorf("workload.type must be one of: ec2-app, k8s-workers")
	}
	if c.Workload.Version != "v1" {
		return fmt.Errorf("workload.version must be 'v1'")
	}

	if c.App.Name == "" {
		return fmt.Errorf("app.name is required")
	}
	if c.App.Environment == "" {
		return fmt.Errorf("app.environment is required")
	}
	if c.App.Region == "" {
		return fmt.Errorf("app.region is required")
	}

	if c.Infrastructure.VpcID == "" {
		return fmt.Errorf("infrastructure.vpc_id is required")
	}
	if c.Infrastructure.SubnetID == "" {
		return fmt.Errorf("infrastructure.subnet_id is required")
	}

	if c.Workload.Type == "k8s-workers" {
		if c.K8s.ControlPlaneInstanceType == "" {
			c.K8s.ControlPlaneInstanceType = "t3.medium"
		}
		if c.K8s.WorkerInstanceType == "" {
			c.K8s.WorkerInstanceType = "t3.medium"
		}
		if c.K8s.WorkerCount == 0 {
			c.K8s.WorkerCount = 2
		}
		if c.K8s.WorkerCount < 1 {
			return fmt.Errorf("k8s.worker_count must be >= 1")
		}
		if c.K8s.KubernetesVersion == "" {
			c.K8s.KubernetesVersion = "1.30"
		}
		if c.K8s.PodCIDR == "" {
			c.K8s.PodCIDR = "10.244.0.0/16"
		}
		if c.K8s.AdminCIDR == "" {
			c.K8s.AdminCIDR = "0.0.0.0/0"
		}
		if c.K8s.EnableSSM == nil {
			v := true
			c.K8s.EnableSSM = &v
		}
		if c.K8s.EnableDetailedMonitoring == nil {
			v := false
			c.K8s.EnableDetailedMonitoring = &v
		}
		return nil
	}

	if c.EC2.InstanceType == "" {
		return fmt.Errorf("ec2.instance_type is required")
	}
	if c.EC2.UserDataMode == "" {
		c.EC2.UserDataMode = "default"
	}
	if !validateUserDataMode(c.EC2.UserDataMode) {
		return fmt.Errorf("ec2.user_data_mode must be one of: default, custom, merge")
	}
	if c.EC2.UserDataMode == "custom" && strings.TrimSpace(c.EC2.UserData) == "" {
		return fmt.Errorf("ec2.user_data is required when ec2.user_data_mode=custom")
	}

	if c.DB.UserDataMode == "" {
		c.DB.UserDataMode = "default"
	}
	if !validateUserDataMode(c.DB.UserDataMode) {
		return fmt.Errorf("db.user_data_mode must be one of: default, custom, merge")
	}
	if c.DB.UserDataMode == "custom" && strings.TrimSpace(c.DB.UserData) == "" {
		return fmt.Errorf("db.user_data is required when db.user_data_mode=custom")
	}
	if c.DB.Mode == "" {
		c.DB.Mode = "ec2"
	}
	if c.DB.Mode != "ec2" && c.DB.Mode != "rds" {
		return fmt.Errorf("db.mode must be one of: ec2, rds")
	}

	if c.DB.Enabled {
		if c.DB.Mode == "ec2" {
			if c.DB.InstanceType == "" {
				c.DB.InstanceType = c.EC2.InstanceType
			}
			if c.DB.Port == 0 {
				c.DB.Port = 1433
			}
		} else {
			if len(c.Infrastructure.SubnetIDs) < 2 && len(c.LB.SubnetIDs) < 2 {
				return fmt.Errorf("db.mode=rds requires at least 2 subnets in infrastructure.subnet_ids or lb.subnet_ids")
			}
			if c.DB.UserDataMode != "default" || strings.TrimSpace(c.DB.UserData) != "" {
				return fmt.Errorf("db.user_data and db.user_data_mode are only supported when db.mode=ec2")
			}
			if c.DB.AMI != "" || c.DB.OS != "" || c.DB.InstanceType != "" {
				return fmt.Errorf("db.instance_type/db.ami/db.os are only supported when db.mode=ec2")
			}
			if c.DB.RDS.InstanceClass == "" {
				c.DB.RDS.InstanceClass = "db.t3.micro"
			}
			if c.DB.RDS.Engine == "" {
				c.DB.RDS.Engine = "postgres"
			}
			if c.DB.RDS.EngineVersion == "" {
				c.DB.RDS.EngineVersion = "16.3"
			}
			if c.DB.RDS.AllocatedStorage == 0 {
				c.DB.RDS.AllocatedStorage = 20
			}
			if c.DB.RDS.StorageType == "" {
				c.DB.RDS.StorageType = "gp3"
			}
			if c.DB.RDS.DBName == "" {
				c.DB.RDS.DBName = "appdb"
			}
			if c.DB.RDS.Username == "" {
				c.DB.RDS.Username = "brainctl"
			}
			if c.DB.RDS.Password == "" {
				return fmt.Errorf("db.rds.password is required when db.mode=rds")
			}
			if c.DB.RDS.BackupRetentionDays == 0 {
				c.DB.RDS.BackupRetentionDays = 7
			}
			if c.DB.Port == 0 {
				c.DB.Port = 5432
			}
		}
	} else {
		if c.DB.Mode == "rds" && strings.TrimSpace(c.DB.RDS.Password) != "" {
			return fmt.Errorf("db.rds.password must be omitted when db.enabled=false")
		}
	}

	if c.LB.InstanceCount == 0 {
		c.LB.InstanceCount = 1
	}
	if c.LB.InstanceCount < 1 {
		return fmt.Errorf("lb.instance_count must be >= 1")
	}

	if c.LB.Enabled {
		if c.LB.Scheme == "" {
			c.LB.Scheme = "private"
		}
		if c.LB.Scheme != "public" && c.LB.Scheme != "private" {
			return fmt.Errorf("lb.scheme must be 'public' or 'private'")
		}
		if c.LB.ListenerPort == 0 {
			c.LB.ListenerPort = 80
		}
		if c.LB.ListenerPort != 80 && c.LB.ListenerPort != 443 {
			return fmt.Errorf("lb.listener_port must be 80 or 443")
		}
		if c.LB.TargetPort == 0 {
			c.LB.TargetPort = 80
		}
		if c.LB.AllowedCIDR == "" {
			c.LB.AllowedCIDR = "0.0.0.0/0"
		}
		if len(c.LB.SubnetIDs) < 2 {
			return fmt.Errorf("lb.subnet_ids must have at least 2 subnets")
		}
	}

	if c.AppScaling.Enabled {
		if !c.LB.Enabled {
			return fmt.Errorf("app_scaling.enabled requires lb.enabled=true")
		}
		if len(c.AppScaling.SubnetIDs) == 0 {
			if len(c.Infrastructure.SubnetIDs) >= 2 {
				c.AppScaling.SubnetIDs = c.Infrastructure.SubnetIDs
			} else {
				c.AppScaling.SubnetIDs = c.LB.SubnetIDs
			}
		}
		if len(c.AppScaling.SubnetIDs) < 2 {
			return fmt.Errorf("app_scaling.subnet_ids must have at least 2 subnets for multi-AZ")
		}
		if c.AppScaling.MinSize == 0 {
			c.AppScaling.MinSize = 2
		}
		if c.AppScaling.MaxSize == 0 {
			c.AppScaling.MaxSize = 4
		}
		if c.AppScaling.DesiredCapacity == 0 {
			c.AppScaling.DesiredCapacity = c.AppScaling.MinSize
		}
		if c.AppScaling.CPUTarget == 0 {
			c.AppScaling.CPUTarget = 60
		}
		if c.AppScaling.MinSize > c.AppScaling.MaxSize {
			return fmt.Errorf("app_scaling.min_size must be <= app_scaling.max_size")
		}
		if c.AppScaling.DesiredCapacity < c.AppScaling.MinSize || c.AppScaling.DesiredCapacity > c.AppScaling.MaxSize {
			return fmt.Errorf("app_scaling.desired_capacity must be between min_size and max_size")
		}
		if c.LB.InstanceCount != 1 {
			return fmt.Errorf("lb.instance_count cannot be used when app_scaling.enabled=true")
		}
	}

	if !c.AppScaling.Enabled && c.LB.InstanceCount > 1 && !c.LB.Enabled {
		return fmt.Errorf("lb.instance_count>1 requires lb.enabled=true")
	}

	if c.Observability.Enabled == nil {
		enabled := true
		c.Observability.Enabled = &enabled
	}
	if c.Observability.EnableSSMEndpoints == nil {
		v := false
		c.Observability.EnableSSMEndpoints = &v
	}
	if c.Observability.EnableSSMPrivateDNS == nil {
		v := false
		c.Observability.EnableSSMPrivateDNS = &v
	}
	if c.Observability.CPUHighThreshold == 0 {
		c.Observability.CPUHighThreshold = 80
	}
	if c.Observability.CPUHighThreshold < 1 || c.Observability.CPUHighThreshold > 100 {
		return fmt.Errorf("observability.cpu_high_threshold must be between 1 and 100")
	}
	if c.Observability.AlertEmail != "" && !strings.Contains(c.Observability.AlertEmail, "@") {
		return fmt.Errorf("observability.alert_email must be a valid email")
	}
	if c.Observability.EnableSSMEndpoints != nil && *c.Observability.EnableSSMEndpoints && (c.Observability.Enabled == nil || !*c.Observability.Enabled) {
		return fmt.Errorf("observability.enable_ssm_endpoints=true requires observability.enabled=true")
	}
	if c.Observability.EnableSSMPrivateDNS != nil && *c.Observability.EnableSSMPrivateDNS && (c.Observability.EnableSSMEndpoints == nil || !*c.Observability.EnableSSMEndpoints) {
		return fmt.Errorf("observability.enable_ssm_private_dns=true requires observability.enable_ssm_endpoints=true")
	}

	if c.Recovery.SnapshotTimeUTC == "" {
		c.Recovery.SnapshotTimeUTC = "03:00"
	}
	if len(c.Recovery.SnapshotTimeUTC) != 5 || c.Recovery.SnapshotTimeUTC[2] != ':' {
		return fmt.Errorf("recovery.snapshot_time_utc must be in HH:MM format")
	}
	hour, err := strconv.Atoi(c.Recovery.SnapshotTimeUTC[0:2])
	if err != nil {
		return fmt.Errorf("recovery.snapshot_time_utc must contain numeric hour")
	}
	minute, err := strconv.Atoi(c.Recovery.SnapshotTimeUTC[3:5])
	if err != nil {
		return fmt.Errorf("recovery.snapshot_time_utc must contain numeric minute")
	}
	if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
		return fmt.Errorf("recovery.snapshot_time_utc must be a valid 24h time")
	}
	if c.Recovery.RetentionDays == 0 {
		c.Recovery.RetentionDays = 7
	}
	if c.Recovery.RetentionDays < 1 || c.Recovery.RetentionDays > 365 {
		return fmt.Errorf("recovery.retention_days must be between 1 and 365")
	}
	if c.Recovery.BackupApp == nil {
		v := true
		c.Recovery.BackupApp = &v
	}
	if c.Recovery.BackupDB == nil {
		v := true
		c.Recovery.BackupDB = &v
	}
	if c.Recovery.EnableRunbooks == nil {
		v := true
		c.Recovery.EnableRunbooks = &v
	}
	if c.Recovery.Drill.ScheduleExpression == "" {
		c.Recovery.Drill.ScheduleExpression = "cron(0 3 1 * ? *)"
	}
	if c.Recovery.Drill.RegisterToTargetGroup == nil {
		v := false
		c.Recovery.Drill.RegisterToTargetGroup = &v
	}
	if c.Recovery.Enabled && *c.Recovery.BackupDB {
		if !c.DB.Enabled {
			return fmt.Errorf("recovery.backup_db=true requires db.enabled=true")
		}
		if c.DB.Mode != "ec2" {
			return fmt.Errorf("recovery.backup_db=true requires db.mode=ec2")
		}
	}
	if c.Recovery.Drill.Enabled {
		if !c.Recovery.Enabled {
			return fmt.Errorf("recovery.drill.enabled=true requires recovery.enabled=true")
		}
		if c.Recovery.EnableRunbooks == nil || !*c.Recovery.EnableRunbooks {
			return fmt.Errorf("recovery.drill.enabled=true requires recovery.enable_runbooks=true")
		}
		if c.Recovery.BackupApp == nil || !*c.Recovery.BackupApp {
			return fmt.Errorf("recovery.drill.enabled=true requires recovery.backup_app=true")
		}
		if c.Observability.Enabled == nil || !*c.Observability.Enabled {
			return fmt.Errorf("recovery.drill.enabled=true requires observability.enabled=true")
		}
		if c.Recovery.Drill.ScheduleExpression == "" {
			return fmt.Errorf("recovery.drill.schedule_expression is required when recovery.drill.enabled=true")
		}
		if c.Recovery.Drill.RegisterToTargetGroup != nil && *c.Recovery.Drill.RegisterToTargetGroup && !c.LB.Enabled {
			return fmt.Errorf("recovery.drill.register_to_target_group=true requires lb.enabled=true")
		}
	}

	return nil
}
