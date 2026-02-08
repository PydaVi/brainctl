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
	} `yaml:"ec2"`

	DB struct {
		Enabled      bool   `yaml:"enabled"`
		InstanceType string `yaml:"instance_type"`
		Port         int    `yaml:"port"`
	} `yaml:"db"`

}

func LoadConfig(path string) (*AppConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var cfg AppConfig
	err = yaml.Unmarshal(data, &cfg)
	if err != nil {
		return nil, err
	}

	return &cfg, nil
}

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
	if c.EC2.OS == "" {
		return fmt.Errorf("ec2.os is required")
	}
	if c.EC2.OS != "windows-2022" {
		return fmt.Errorf("ec2.os unsupported: %s (supported: windows-2022)", c.EC2.OS)
	}
	
	if c.DB.Enabled {
		if c.DB.InstanceType == "" {
			c.DB.InstanceType = "t3.micro"
		}
		if c.DB.Port == 0 {
			c.DB.Port = 1433
		}
		if c.DB.Port < 1 || c.DB.Port > 65535 {
			return fmt.Errorf("db.port must be between 1 and 65535")
		}
	}

	return nil
}

