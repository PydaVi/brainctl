// Package terragrunt fornece a camada de execução da CLI Terragrunt.
// Este stub existe para separar explicitamente a orquestração (Terragrunt)
// da UX da CLI brainctl enquanto a implementação é construída.
package terragrunt

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
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) Init() error {
	return nil
}

// Plan executa um plan sem arquivo de saída.
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) Plan() error {
	return nil
}

// PlanOut executa um plan e salva no arquivo informado.
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) PlanOut(planFile string) error {
	return nil
}

// Apply executa apply, opcionalmente com auto-approve.
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) Apply(autoApprove bool) error {
	return nil
}

// Destroy executa destroy, opcionalmente com auto-approve.
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) Destroy(autoApprove bool) error {
	return nil
}

// OutputJSON retorna o output do Terragrunt em JSON.
// Stub: a implementação real chamará o binário terragrunt.
func (r *Runner) OutputJSON() ([]byte, error) {
	return nil, nil
}
