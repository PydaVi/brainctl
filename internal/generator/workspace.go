// Package generator gera o workspace Terragrunt a partir do AppConfig.
// Este stub explicita a responsabilidade de geração sem reimplementar Terraform.
package generator

// WorkspaceGenerator encapsula a geração de arquivos do workspace.
// Manter uma struct dedicada evita funções globais e facilita testes futuros.
type WorkspaceGenerator struct{}

// NewWorkspaceGenerator cria um gerador vazio enquanto a interface é definida.
func NewWorkspaceGenerator() *WorkspaceGenerator {
	return &WorkspaceGenerator{}
}

// Generate cria o workspace Terragrunt a partir do AppConfig.
// Stub: a implementação real vai gerar terragrunt.hcl via text/template.
func (g *WorkspaceGenerator) Generate() error {
	return nil
}
