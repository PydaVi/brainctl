package cli

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/PydaVi/brainctl/internal/config"
	"github.com/PydaVi/brainctl/internal/generator"
	"github.com/PydaVi/brainctl/internal/workspace"
)

type RuntimeOptions struct {
	File          string
	StackDir      string
	OverridesFile string
}

type RuntimeConfig struct {
	App  *config.AppConfig
	Opts RuntimeOptions
}

func LoadRuntimeConfig(opts RuntimeOptions) (*RuntimeConfig, error) {
	cfgPath := opts.File
	if !filepath.IsAbs(cfgPath) {
		cfgPath = filepath.Join(opts.StackDir, opts.File)
	}

	cfg, err := config.LoadConfig(cfgPath)
	if err != nil {
		return nil, err
	}

	if err := config.ResolveUserDataFiles(cfg, opts.StackDir); err != nil {
		return nil, err
	}

	if opts.OverridesFile != "" {
		oPath := opts.OverridesFile
		if !filepath.IsAbs(oPath) {
			oPath = filepath.Join(opts.StackDir, opts.OverridesFile)
		}
		if _, statErr := os.Stat(oPath); statErr == nil {
			if err := config.ApplyOverridesFile(cfg, oPath); err != nil {
				return nil, err
			}
		} else if !errors.Is(statErr, os.ErrNotExist) {
			return nil, statErr
		}
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return &RuntimeConfig{App: cfg, Opts: opts}, nil
}

func (r *RuntimeConfig) PrepareWorkspace() (string, error) {
	wsDir, err := workspace.Prepare(r.App)
	if err != nil {
		return "", err
	}
	if err := generator.Generate(wsDir, r.App); err != nil {
		return "", err
	}
	return wsDir, nil
}
