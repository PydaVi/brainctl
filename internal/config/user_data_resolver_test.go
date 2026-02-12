package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestResolveUserDataFiles(t *testing.T) {
	t.Parallel()

	stackDir := t.TempDir()
	appPath := filepath.Join(stackDir, "scripts", "app-user-data.ps1")
	dbPath := filepath.Join(stackDir, "scripts", "db-user-data.ps1")
	if err := os.MkdirAll(filepath.Dir(appPath), 0o755); err != nil {
		t.Fatalf("mkdir scripts: %v", err)
	}
	if err := os.WriteFile(appPath, []byte("Write-Host 'app'"), 0o644); err != nil {
		t.Fatalf("write app script: %v", err)
	}
	if err := os.WriteFile(dbPath, []byte("Write-Host 'db'"), 0o644); err != nil {
		t.Fatalf("write db script: %v", err)
	}

	cfg := &AppConfig{}
	cfg.EC2.UserData = "file://scripts/app-user-data.ps1"
	cfg.DB.UserData = dbPath

	if err := ResolveUserDataFiles(cfg, stackDir); err != nil {
		t.Fatalf("ResolveUserDataFiles: %v", err)
	}
	if strings.TrimSpace(cfg.EC2.UserData) != "Write-Host 'app'" {
		t.Fatalf("unexpected ec2 user_data: %q", cfg.EC2.UserData)
	}
	if strings.TrimSpace(cfg.DB.UserData) != "Write-Host 'db'" {
		t.Fatalf("unexpected db user_data: %q", cfg.DB.UserData)
	}
}

func TestResolveUserDataFiles_FilePrefixMissing(t *testing.T) {
	t.Parallel()

	cfg := &AppConfig{}
	cfg.EC2.UserData = "file://scripts/missing.ps1"

	err := ResolveUserDataFiles(cfg, t.TempDir())
	if err == nil {
		t.Fatalf("expected error for missing file:// path")
	}
}
