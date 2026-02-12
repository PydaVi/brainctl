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
}
