package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfigAndValidate_MinimalValidConfig(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "app.yaml")

	yaml := `app:
  name: brainctl-app
  environment: dev
  region: us-east-1
infrastructure:
  vpc_id: vpc-123456
  subnet_id: subnet-123456
ec2:
  instance_type: t3.micro
  os: windows
  ami: ami-123456
  user_data_mode: default
`

	if err := os.WriteFile(cfgPath, []byte(yaml), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := LoadConfig(cfgPath)
	if err != nil {
		t.Fatalf("load config: %v", err)
	}

	if err := cfg.Validate(); err != nil {
		t.Fatalf("validate config: %v", err)
	}

	if cfg.Workload.Type != "ec2-app" {
		t.Fatalf("expected default workload.type=ec2-app, got %q", cfg.Workload.Type)
	}
	if cfg.Workload.Version != "v1" {
		t.Fatalf("expected default workload.version=v1, got %q", cfg.Workload.Version)
	}
}

func TestValidate_InvalidWorkloadVersion(t *testing.T) {
	t.Parallel()

	cfg := &AppConfig{}
	cfg.Workload.Type = "ec2-app"
	cfg.Workload.Version = "v2"
	cfg.App.Name = "brainctl-app"
	cfg.App.Environment = "dev"
	cfg.App.Region = "us-east-1"
	cfg.Infrastructure.VpcID = "vpc-123"
	cfg.Infrastructure.SubnetID = "subnet-123"
	cfg.EC2.InstanceType = "t3.micro"
	cfg.EC2.UserDataMode = "default"

	err := cfg.Validate()
	if err == nil || err.Error() != "workload.version must be 'v1'" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_SSMEndpointsRequiresObservability(t *testing.T) {
	t.Parallel()

	cfg := &AppConfig{}
	cfg.Workload.Type = "ec2-app"
	cfg.Workload.Version = "v1"
	cfg.App.Name = "brainctl-app"
	cfg.App.Environment = "dev"
	cfg.App.Region = "us-east-1"
	cfg.Infrastructure.VpcID = "vpc-123"
	cfg.Infrastructure.SubnetID = "subnet-123"
	cfg.EC2.InstanceType = "t3.micro"
	cfg.EC2.UserDataMode = "default"

	obsEnabled := false
	ssmEndpoints := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Observability.EnableSSMEndpoints = &ssmEndpoints

	err := cfg.Validate()
	if err == nil || err.Error() != "observability.enable_ssm_endpoints=true requires observability.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_SSMPrivateDNSRequiresEndpoints(t *testing.T) {
	t.Parallel()

	cfg := &AppConfig{}
	cfg.Workload.Type = "ec2-app"
	cfg.Workload.Version = "v1"
	cfg.App.Name = "brainctl-app"
	cfg.App.Environment = "dev"
	cfg.App.Region = "us-east-1"
	cfg.Infrastructure.VpcID = "vpc-123"
	cfg.Infrastructure.SubnetID = "subnet-123"
	cfg.EC2.InstanceType = "t3.micro"
	cfg.EC2.UserDataMode = "default"

	obsEnabled := true
	ssmEndpoints := false
	ssmPrivateDNS := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Observability.EnableSSMEndpoints = &ssmEndpoints
	cfg.Observability.EnableSSMPrivateDNS = &ssmPrivateDNS

	err := cfg.Validate()
	if err == nil || err.Error() != "observability.enable_ssm_private_dns=true requires observability.enable_ssm_endpoints=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}
