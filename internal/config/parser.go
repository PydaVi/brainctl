package config

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// AppConfig representa o contrato declarativo consumido pelo brainctl.
// A ideia é manter o YAML simples para o usuário, enquanto a lógica de
// orquestração é aplicada pelo Go + módulos Terraform.
type AppConfig struct {
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

	// RuntimeOverrides são alterações aplicadas por overrides.yaml (não fazem parte do contrato base).
	RuntimeOverrides RuntimeOverrides `yaml:"-"`
}

// DBConfig define o bloco opcional de banco.
type DBConfig struct {
	Enabled      bool   `yaml:"enabled"`
	InstanceType string `yaml:"instance_type"`
	Port         int    `yaml:"port"`
	OS           string `yaml:"os"`
	AMI          string `yaml:"ami"`
	UserData     string `yaml:"user_data"`
	UserDataMode string `yaml:"user_data_mode"`
}

// LBConfig define parâmetros de load balancer.
type LBConfig struct {
	Enabled      bool     `yaml:"enabled"`
	Scheme       string   `yaml:"scheme"`
	SubnetIDs    []string `yaml:"subnet_ids"`
	ListenerPort int      `yaml:"listener_port"`
	TargetPort   int      `yaml:"target_port"`
	AllowedCIDR  string   `yaml:"allowed_cidr"`
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
	Enabled          *bool  `yaml:"enabled"`
	CPUHighThreshold int    `yaml:"cpu_high_threshold"`
	AlertEmail       string `yaml:"alert_email"`
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

// Validate aplica regras e defaults do contrato declarativo.
func (c *AppConfig) Validate() error {
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

	if c.DB.Enabled {
		if c.DB.InstanceType == "" {
			c.DB.InstanceType = c.EC2.InstanceType
		}
		if c.DB.Port == 0 {
			c.DB.Port = 1433
		}
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
	}

	if c.Observability.Enabled == nil {
		enabled := true
		c.Observability.Enabled = &enabled
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

	return nil
}