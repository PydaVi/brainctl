package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type AppConfig struct {
	App struct {
		Name        string `yaml:"name"`
		Environment string `yaml:"environment"`
		Region      string `yaml:"region"`
	} `yaml:"app"`

	Infrastructure struct {
		VpcID    string `yaml:"vpc_id"`
		SubnetID string `yaml:"subnet_id"`
	} `yaml:"infrastructure"`

	EC2 struct {
		InstanceType string `yaml:"instance_type"`
		OS           string `yaml:"os"`
		AMI          string `yaml:"ami"` // opcional (se vazio, usa data.aws_ami no módulo)
	} `yaml:"ec2"`

	// DB é opcional (se Enabled=false, não cria nada)
	DB DBConfig `yaml:"db"`

	// LB é opcional (se Enabled=false, não cria nada)
	LB LBConfig `yaml:"lb"`
}

type DBConfig struct {
	Enabled      bool   `yaml:"enabled"` // ✅ bate com app.yaml (db.enabled)
	InstanceType string `yaml:"instance_type"`
	Port         int    `yaml:"port"`
	OS           string `yaml:"os"`  // opcional
	AMI          string `yaml:"ami"` // opcional
}

type LBConfig struct {
	Enabled      bool     `yaml:"enabled"`
	Scheme       string   `yaml:"scheme"` // public | private
	SubnetIDs    []string `yaml:"subnet_ids"`
	ListenerPort int      `yaml:"listener_port"` // 80/443
	TargetPort   int      `yaml:"target_port"`   // porta da app no target group
	AllowedCIDR  string   `yaml:"allowed_cidr"`  // quem acessa o ALB
}

// LoadConfig carrega app.yaml
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

func (c *AppConfig) Validate() error {
	// app
	if c.App.Name == "" {
		return fmt.Errorf("app.name is required")
	}
	if c.App.Environment == "" {
		return fmt.Errorf("app.environment is required")
	}
	if c.App.Region == "" {
		return fmt.Errorf("app.region is required")
	}

	// infra (obrigatório)
	if c.Infrastructure.VpcID == "" {
		return fmt.Errorf("infrastructure.vpc_id is required")
	}
	if c.Infrastructure.SubnetID == "" {
		return fmt.Errorf("infrastructure.subnet_id is required")
	}

	// ec2 app (obrigatório)
	if c.EC2.InstanceType == "" {
		return fmt.Errorf("ec2.instance_type is required")
	}

	// defaults DB
	if c.DB.Enabled {
		if c.DB.InstanceType == "" {
			c.DB.InstanceType = c.EC2.InstanceType
		}
		if c.DB.Port == 0 {
			c.DB.Port = 1433
		}
	}

	// defaults LB
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
			return fmt.Errorf("lb.listener_port must be 80 or 443 (for now)")
		}

		if c.LB.TargetPort == 0 {
			c.LB.TargetPort = 80
		}

		if c.LB.AllowedCIDR == "" {
			c.LB.AllowedCIDR = "0.0.0.0/0"
		}

		// ALB exige 2+ subnets em AZs diferentes (na prática). Vamos exigir pelo menos 2.
		if len(c.LB.SubnetIDs) < 2 {
			return fmt.Errorf("lb.subnet_ids must have at least 2 subnets")
		}
	}

	return nil
}
