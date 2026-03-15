# ADR-001: Usar Terragrunt ao invés de orquestração própria

## Status
Aceito

## Contexto
O brainctl v1 implementou sua própria camada de orquestração Terraform em Go:
geração de backend.tf, main.tf, execução sequencial de comandos terraform.
Essa abordagem funciona, mas reinventa o que Terragrunt já resolve de forma
madura: DRY de configuração, herança de backend, dependências entre módulos,
execução paralela com grafo de dependências.

A reforma foi motivada por feedback direto da comunidade indicando que aprender
Terragrunt é mais valioso do que manter uma reimplementação parcial.

## Decisão
Substituir a orquestração Go por Terragrunt. A CLI brainctl mantém seu papel
como camada de UX (contrato YAML → workspace Terragrunt → execução), mas
delega toda a orquestração ao Terragrunt.

## Consequências
- Positivo: DRY de backend e configuração entre ambientes sem código Go extra
- Positivo: dependências entre módulos declarativas via `dependency {}` blocks
- Positivo: compatível com o ecossistema Terragrunt (hooks, run-all, etc.)
- Negativo: adiciona Terragrunt como dependência do ambiente de execução
- Negativo: times precisam entender Terragrunt para depurar problemas avançados
