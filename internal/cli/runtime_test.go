package cli

import (
	"os"
	"path/filepath"
	"testing"
)

const testAppYAML = `
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

func TestLoadRuntimeConfigWithRelativePaths(t *testing.T) {
	stackDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(stackDir, "app.yaml"), []byte(testAppYAML), 0o644); err != nil {
		t.Fatalf("write app.yaml: %v", err)
	}
	if err := os.WriteFile(filepath.Join(stackDir, "overrides.yaml"), []byte("overrides: []\n"), 0o644); err != nil {
		t.Fatalf("write overrides.yaml: %v", err)
	}

	cfg, err := LoadRuntimeConfig(RuntimeOptions{File: "app.yaml", StackDir: stackDir, OverridesFile: "overrides.yaml"})
	if err != nil {
		t.Fatalf("LoadRuntimeConfig failed: %v", err)
	}

	if cfg.App.App.Name != "test" {
		t.Fatalf("unexpected app name: %s", cfg.App.App.Name)
	}
}

func TestLoadRuntimeConfigIgnoresMissingOverrides(t *testing.T) {
	stackDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(stackDir, "app.yaml"), []byte(testAppYAML), 0o644); err != nil {
		t.Fatalf("write app.yaml: %v", err)
	}

	_, err := LoadRuntimeConfig(RuntimeOptions{File: "app.yaml", StackDir: stackDir, OverridesFile: "missing.yaml"})
	if err != nil {
		t.Fatalf("expected missing overrides to be ignored, got: %v", err)
	}
}
