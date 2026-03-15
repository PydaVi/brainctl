// Package terragrunt fornece a camada de execução da CLI Terragrunt.
// Usamos os/exec porque não existe uma biblioteca Go estável do Terragrunt;
// delegar ao binário oficial reduz acoplamento e mantém compatibilidade.
package terragrunt

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
)

// Runner executa comandos Terragrunt dentro de um workspace gerado.
// O campo wsDir é mantido explícito para evitar dependência implícita de cwd.
type Runner struct {
	wsDir string
}

// NewRunner constrói o runner com o diretório de workspace.
// A assinatura simples facilita o uso pela camada de CLI sem acoplamento extra.
func NewRunner(wsDir string) *Runner {
	return &Runner{wsDir: wsDir}
}

// Init prepara o backend e módulos via Terragrunt.
func (r *Runner) Init() error {
	return r.run("init")
}

// Plan executa um plan sem arquivo de saída.
func (r *Runner) Plan() error {
	return r.run("plan")
}

// PlanOut executa um plan e salva no arquivo informado.
func (r *Runner) PlanOut(planFile string) error {
	if planFile == "" {
		return fmt.Errorf("plan file is required")
	}
	return r.run("plan", "-out", planFile)
}

// Apply executa apply, opcionalmente com auto-approve.
func (r *Runner) Apply(autoApprove bool) error {
	args := []string{"apply"}
	if autoApprove {
		args = append(args, "-auto-approve")
	}
	return r.run(args...)
}

// Destroy executa destroy, opcionalmente com auto-approve.
func (r *Runner) Destroy(autoApprove bool) error {
	args := []string{"destroy"}
	if autoApprove {
		args = append(args, "-auto-approve")
	}
	return r.run(args...)
}

// OutputJSON retorna o output do Terragrunt em JSON.
func (r *Runner) OutputJSON() ([]byte, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	cmd := exec.Command("terragrunt", "output", "-json")
	cmd.Dir = r.wsDir
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("terragrunt output -json: %w: %s", err, stderr.String())
	}
	return stdout.Bytes(), nil
}

func (r *Runner) run(args ...string) error {
	if r.wsDir == "" {
		return fmt.Errorf("workspace dir is required")
	}

	cmd := exec.Command("terragrunt", args...)
	cmd.Dir = r.wsDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("terragrunt %s: %w", args[0], err)
	}
	return nil
}
