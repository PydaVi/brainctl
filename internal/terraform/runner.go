package terraform

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
)

// Runner encapsula a execução do Terraform dentro de um diretório de workspace.
// Ele é usado pelos comandos `plan`, `apply`, `destroy`, `status` e `output`.
type Runner struct {
	Dir string
}

// NewRunner cria um runner apontando para o workspace Terraform gerado.
func NewRunner(dir string) *Runner {
	return &Runner{Dir: dir}
}

// Init prepara providers, backend remoto e módulos no workspace.
func (r *Runner) Init() error {
	return r.run("init", "-reconfigure", "-input=false", "-no-color")
}

// Plan executa o plano padrão do Terraform.
func (r *Runner) Plan() error {
	return r.run("plan", "-input=false", "-no-color")
}

// PlanDetailed roda plan com -detailed-exitcode.
// Retorna hasChanges=true quando o terraform retornar exit code 2.
func (r *Runner) PlanDetailed() (hasChanges bool, err error) {
	cmd := exec.Command("terraform", "plan", "-input=false", "-no-color", "-detailed-exitcode")
	cmd.Dir = r.Dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err = cmd.Run()
	if err == nil {
		return false, nil // exit code 0 => sem mudanças
	}

	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		switch exitErr.ExitCode() {
		case 2:
			return true, nil // plan ok, com mudanças
		default:
			return false, fmt.Errorf("terraform plan failed (exit=%d): %w", exitErr.ExitCode(), err)
		}
	}

	return false, fmt.Errorf("terraform plan failed: %w", err)
}

// Apply aplica mudanças no ambiente.
// Se autoApprove=true, ignora prompt interativo.
func (r *Runner) Apply(autoApprove bool) error {
	args := []string{"apply", "-input=false", "-no-color"}
	if autoApprove {
		args = append(args, "-auto-approve")
	}
	return r.run(args...)
}

// Destroy remove recursos do workspace.
// Se autoApprove=true, ignora prompt interativo.
func (r *Runner) Destroy(autoApprove bool) error {
	args := []string{"destroy", "-input=false", "-no-color"}
	if autoApprove {
		args = append(args, "-auto-approve")
	}
	return r.run(args...)
}

// OutputJSON retorna o stdout do `terraform output -json`.
func (r *Runner) OutputJSON() ([]byte, error) {
	cmd := exec.Command("terraform", "output", "-json", "-no-color")
	cmd.Dir = r.Dir

	var out bytes.Buffer
	var errOut bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errOut

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("terraform output failed: %w\n%s", err, errOut.String())
	}
	return out.Bytes(), nil
}

// StatePull tenta puxar o state remoto.
// No MVP, qualquer erro é tratado como state ausente/inacessível.
func (r *Runner) StatePull() (present bool, err error) {
	cmd := exec.Command("terraform", "state", "pull")
	cmd.Dir = r.Dir

	var out bytes.Buffer
	var errOut bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errOut

	if err := cmd.Run(); err != nil {
		return false, nil
	}
	return true, nil
}

// run centraliza execução de comandos Terraform no diretório do workspace.
func (r *Runner) run(args ...string) error {
	cmd := exec.Command("terraform", args...)
	cmd.Dir = r.Dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}
