package cli

import (
	"os"
	"path/filepath"
	"testing"
)

const testAppYAML = `
terraform:
  backend:
    bucket: brainctl-test-state
app:
  name: test
  environment: dev
  region: us-east-1
infrastructure:
  vpc_id: vpc-123
  subnet_id: subnet-1
ec2:
  instance_type: t3.micro
db:
  enabled: false
lb:
  enabled: false
app_scaling:
  enabled: false
observability:
  enabled: true
recovery:
  enabled: false
`

func TestLoadRuntimeConfigWithSecurityGroupsDir(t *testing.T) {
	stackDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(stackDir, "app.yaml"), []byte(testAppYAML), 0o644); err != nil {
		t.Fatalf("write app.yaml: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(stackDir, "security-groups"), 0o755); err != nil {
		t.Fatalf("mkdir security-groups: %v", err)
	}
	if err := os.WriteFile(filepath.Join(stackDir, "security-groups", "app.yaml"), []byte("group: app\ningress: []\n"), 0o644); err != nil {
		t.Fatalf("write security-groups file: %v", err)
	}

	cfg, err := LoadRuntimeConfig(RuntimeOptions{File: "app.yaml", StackDir: stackDir, SecurityGroupsDir: "security-groups"})
	if err != nil {
		t.Fatalf("LoadRuntimeConfig failed: %v", err)
	}

	if cfg.App.App.Name != "test" {
		t.Fatalf("unexpected app name: %s", cfg.App.App.Name)
	}
}

func TestLoadRuntimeConfigIgnoresMissingSecurityGroupsDir(t *testing.T) {
	stackDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(stackDir, "app.yaml"), []byte(testAppYAML), 0o644); err != nil {
		t.Fatalf("write app.yaml: %v", err)
	}

	_, err := LoadRuntimeConfig(RuntimeOptions{File: "app.yaml", StackDir: stackDir, SecurityGroupsDir: "missing-dir"})
	if err != nil {
		t.Fatalf("expected missing security-groups dir to be ignored, got: %v", err)
	}
}
