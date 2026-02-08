package workspace

import (
	"os"
	"path/filepath"
	"github.com/PydaVi/brainctl/internal/config"
)

func Prepare(cfg *config.AppConfig) (string, error) {

	wsDir := filepath.Join(
		".brainctl",
		"apps",
		cfg.App.Name,
		cfg.App.Environment,
	)

	err := os.MkdirAll(wsDir, 0755)
	if err != nil {
		return "", err
	}

	return wsDir, nil
}
