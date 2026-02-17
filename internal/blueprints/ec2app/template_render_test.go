package ec2app

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/PydaVi/brainctl/internal/config"
)

func TestGenerateRendersWithPrivateEndpointsFields(t *testing.T) {
	t.Parallel()
	stackDir := t.TempDir()
	cfgPath := filepath.Join(stackDir, "app.yaml")
	wsDir := filepath.Join(stackDir, "ws")
	if err := os.MkdirAll(wsDir, 0o755); err != nil {
		t.Fatalf("mkdir ws: %v", err)
	}

	yaml := `
workload:
  type: ec2-app
  version: v1
app:
  name: brain-test
  environment: dev
  region: us-east-1
infrastructure:
  vpc_id: vpc-123
  subnet_id: subnet-a
  subnet_ids:
    - subnet-a
    - subnet-b
ec2:
  instance_type: t3.micro
lb:
  enabled: true
  subnet_ids:
    - subnet-a
    - subnet-b
observability:
  enabled: true
  enable_private_endpoints: true
  enable_ssm_endpoints: true
  endpoint_subnet_ids:
    - subnet-a
    - subnet-b
recovery:
  enabled: false
db:
  enabled: false
`
	if err := os.WriteFile(cfgPath, []byte(yaml), 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := config.LoadConfig(cfgPath)
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("validate: %v", err)
	}

	if err := Generate(wsDir, cfg); err != nil {
		t.Fatalf("generate failed: %v", err)
	}
}
