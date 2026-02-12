package blueprints

import (
	"fmt"
	"sort"

	"github.com/PydaVi/brainctl/internal/blueprints/ec2app"
	"github.com/PydaVi/brainctl/internal/config"
)

const (
	DefaultWorkloadType    = "ec2-app"
	DefaultWorkloadVersion = "v1"
)

// Definition descreve um blueprint disponível no catálogo do brainctl.
type Definition struct {
	Type        string
	Version     string
	Description string
	Generate    func(wsDir string, cfg *config.AppConfig) error
}

var catalog = []Definition{
	{
		Type:        "ec2-app",
		Version:     "v1",
		Description: "EC2 app com opções de ALB/ASG, observabilidade e recovery",
		Generate:    ec2app.Generate,
	},
}

// List retorna o catálogo ordenado por type/version.
func List() []Definition {
	out := make([]Definition, len(catalog))
	copy(out, catalog)
	sort.Slice(out, func(i, j int) bool {
		if out[i].Type == out[j].Type {
			return out[i].Version < out[j].Version
		}
		return out[i].Type < out[j].Type
	})
	return out
}

// Resolve encontra o blueprint por type/version.
func Resolve(workloadType, version string) (Definition, error) {
	if workloadType == "" {
		workloadType = DefaultWorkloadType
	}
	if version == "" {
		version = DefaultWorkloadVersion
	}

	for _, b := range catalog {
		if b.Type == workloadType && b.Version == version {
			return b, nil
		}
	}
	return Definition{}, fmt.Errorf("unsupported workload %q version %q", workloadType, version)
}
