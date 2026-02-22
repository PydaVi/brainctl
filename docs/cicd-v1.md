# CI/CD v1

## English

This document describes a minimal CI/CD baseline for `brainctl` stacks, focused on validation, planning, controlled apply, and governance.

### 1. Recommended pipeline stages

1. **Lint & format**: YAML checks and Terraform formatting.
2. **Contract validation**: run `brainctl plan` in each stack to validate schema and guardrails.
3. **Terraform plan artifact**: persist plan output for review.
4. **Approval gate**: require manual approval for production apply.
5. **Apply**: run `brainctl apply` in the approved target stack.
6. **Post-apply checks**: run `brainctl status` and `brainctl output`.

### 2. Suggested commands

```bash
go test ./...
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/prod
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
```

For deployment steps:

```bash
go run ./cmd/brainctl apply --stack-dir <stack-dir>
go run ./cmd/brainctl status --stack-dir <stack-dir>
go run ./cmd/brainctl output --stack-dir <stack-dir>
```

### 3. Governance recommendations

- Enforce pull request review before production apply.
- Keep Terraform backend configuration in contract (`terraform.backend`).
- Separate state by app/environment using `key_prefix`.
- Use environment-scoped credentials/roles.
- Keep recovery and observability enabled for critical workloads.

---

## Português

Este documento descreve uma linha de base mínima de CI/CD para stacks do `brainctl`, focada em validação, planejamento, apply controlado e governança.

### 1. Estágios recomendados de pipeline

1. **Lint e formatação**: checagem de YAML e formatação Terraform.
2. **Validação de contrato**: executar `brainctl plan` em cada stack para validar schema e guardrails.
3. **Artefato de Terraform plan**: persistir saída do plano para revisão.
4. **Gate de aprovação**: exigir aprovação manual para apply em produção.
5. **Apply**: executar `brainctl apply` na stack aprovada.
6. **Checagens pós-apply**: executar `brainctl status` e `brainctl output`.

### 2. Comandos sugeridos

```bash
go test ./...
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/prod
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
```

Para etapas de deploy:

```bash
go run ./cmd/brainctl apply --stack-dir <stack-dir>
go run ./cmd/brainctl status --stack-dir <stack-dir>
go run ./cmd/brainctl output --stack-dir <stack-dir>
```

### 3. Recomendações de governança

- Exigir revisão de pull request antes de apply em produção.
- Manter configuração do backend Terraform no contrato (`terraform.backend`).
- Separar state por app/ambiente usando `key_prefix`.
- Usar credenciais/roles segmentadas por ambiente.
- Manter recovery e observabilidade habilitados para workloads críticos.
