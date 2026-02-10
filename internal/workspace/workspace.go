package workspace

import (
	"os"
	"path/filepath"

	"github.com/PydaVi/brainctl/internal/config"
)

// Prepare garante a criação do workspace local por aplicação/ambiente.
// Exemplo de caminho gerado: .brainctl/apps/<app>/<env>/
func Prepare(cfg *config.AppConfig) (string, error) {
	wsDir := filepath.Join(
		".brainctl",
		"apps",
		cfg.App.Name,
		cfg.App.Environment,
	)

	if err := os.MkdirAll(wsDir, 0o755); err != nil {
		return "", err
	}

	return wsDir, nil
}