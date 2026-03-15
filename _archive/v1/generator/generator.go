package generator

import (
	"fmt"

	"github.com/PydaVi/brainctl/internal/blueprints"
	"github.com/PydaVi/brainctl/internal/config"
)

// Generate renderiza o workspace Terraform conforme o blueprint do workload.
func Generate(wsDir string, cfg *config.AppConfig) error {
	bp, err := blueprints.Resolve(cfg.Workload.Type, cfg.Workload.Version)
	if err != nil {
		return err
	}
	if err := bp.Generate(wsDir, cfg); err != nil {
		return fmt.Errorf("generate workload %s@%s: %w", bp.Type, bp.Version, err)
	}
	return nil
}
