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
	if err == nil || err.Error() != "observability.enable_ssm_private_dns=true requires observability.enable_private_endpoints=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func minimalValidConfig() *AppConfig {
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
	return cfg
}

func TestValidate_RecoveryDrillRequiresRecoveryEnabled(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	obsEnabled := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Recovery.Drill.Enabled = true

	err := cfg.Validate()
	if err == nil || err.Error() != "recovery.drill.enabled=true requires recovery.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_RecoveryDrillRegisterTGRequiresLB(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	obsEnabled := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Recovery.Enabled = true
	cfg.DB.Enabled = true
	cfg.Recovery.Drill.Enabled = true
	v := true
	cfg.Recovery.Drill.RegisterToTargetGroup = &v

	err := cfg.Validate()
	if err == nil || err.Error() != "recovery.drill.register_to_target_group=true requires lb.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_LBInstanceCountDefault(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	if err := cfg.Validate(); err != nil {
		t.Fatalf("validate failed: %v", err)
	}
	if cfg.LB.InstanceCount != 1 {
		t.Fatalf("expected lb.instance_count default=1, got %d", cfg.LB.InstanceCount)
	}
}

func TestValidate_LBInstanceCountWithASGIsInvalid(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	cfg.LB.Enabled = true
	cfg.LB.SubnetIDs = []string{"subnet-a", "subnet-b"}
	cfg.LB.InstanceCount = 2
	cfg.AppScaling.Enabled = true
	cfg.AppScaling.SubnetIDs = []string{"subnet-a", "subnet-b"}

	err := cfg.Validate()
	if err == nil || err.Error() != "lb.instance_count cannot be used when app_scaling.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_LBInstanceCountGreaterThanOneRequiresLB(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	cfg.LB.InstanceCount = 2

	err := cfg.Validate()
	if err == nil || err.Error() != "lb.instance_count>1 requires lb.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_DBModeRDSRequiresPassword(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	cfg.DB.Enabled = true
	cfg.DB.Mode = "rds"
	cfg.Infrastructure.SubnetIDs = []string{"subnet-a", "subnet-b"}

	err := cfg.Validate()
	if err == nil || err.Error() != "db.rds.password is required when db.mode=rds" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_RecoveryBackupDBRequiresEC2Mode(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	cfg.DB.Enabled = true
	cfg.DB.Mode = "rds"
	cfg.Infrastructure.SubnetIDs = []string{"subnet-a", "subnet-b"}
	cfg.DB.RDS.Password = "super-secret"
	cfg.Recovery.Enabled = true
	v := true
	cfg.Recovery.BackupDB = &v

	err := cfg.Validate()
	if err == nil || err.Error() != "recovery.backup_db=true requires db.mode=ec2" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_PrivateEndpointsRequireObservability(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	obsEnabled := false
	privateEndpoints := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Observability.EnablePrivateEndpoints = &privateEndpoints

	err := cfg.Validate()
	if err == nil || err.Error() != "observability.enable_private_endpoints=true requires observability.enabled=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_SSMEndpointsRequirePrivateEndpoints(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	obsEnabled := true
	ssmEndpoints := true
	privateEndpoints := false
	cfg.Observability.Enabled = &obsEnabled
	cfg.Observability.EnableSSMEndpoints = &ssmEndpoints
	cfg.Observability.EnablePrivateEndpoints = &privateEndpoints

	err := cfg.Validate()
	if err == nil || err.Error() != "observability.enable_ssm_endpoints=true requires observability.enable_private_endpoints=true" {
		t.Fatalf("unexpected validate error: %v", err)
	}
}

func TestValidate_PrivateEndpointsPopulateSubnetIDs(t *testing.T) {
	t.Parallel()
	cfg := minimalValidConfig()
	obsEnabled := true
	privateEndpoints := true
	cfg.Observability.Enabled = &obsEnabled
	cfg.Observability.EnablePrivateEndpoints = &privateEndpoints
	cfg.Infrastructure.SubnetIDs = []string{"subnet-a", "subnet-b"}

	if err := cfg.Validate(); err != nil {
		t.Fatalf("validate failed: %v", err)
	}
	if len(cfg.Observability.EndpointSubnetIDs) != 2 {
		t.Fatalf("expected endpoint_subnet_ids to be defaulted with 2 subnets, got %d", len(cfg.Observability.EndpointSubnetIDs))
	}
}
