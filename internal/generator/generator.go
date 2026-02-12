package generator

import (
	"fmt"

	"github.com/PydaVi/brainctl/internal/blueprints/ec2app"
	"github.com/PydaVi/brainctl/internal/config"
)

const defaultWorkloadType = "ec2-app"

// Generate renderiza o workspace Terraform conforme o blueprint do workload.
func Generate(wsDir string, cfg *config.AppConfig) error {
	workloadType := cfg.Workload.Type
	if workloadType == "" {
		workloadType = defaultWorkloadType
	}

	switch workloadType {
	case "ec2-app":
		return ec2app.Generate(wsDir, cfg)
	default:
		return fmt.Errorf("unsupported workload.type %q", workloadType)
	}
}
