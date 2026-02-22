# CI/CD v1.0 do brainctl (simples, mas já orientado a Terraform)

Este guia implementa uma versão inicial para você entender o fluxo completo:
- branch -> PR
- preview de Terraform no PR (`plan` + `cost`)
- testes Go após preview
- `apply` automático depois do merge

## O que foi criado

- `/.github/workflows/ci.yml`
  - Em Pull Request para `main` com branch de origem `feat/*`:
    1. lê `stack_dir` e `environment` do body do PR
    2. roda:
       - `go run ./cmd/brainctl plan --stack-dir <stack_dir>`
       - `go run ./cmd/brainctl cost --stack-dir <stack_dir>`
    3. publica outputs (`plan-output.txt`, `cost-output.txt`) como artifact
    4. roda qualidade Go:
       - `gofmt` check
       - `go vet ./...`
       - `go test ./...`
  - Em push em branches `feat/*`: roda os checks Go (`gofmt`, `go vet`, `go test`)

- `/.github/workflows/cd-v1.yml`
  - Quando PR para `main` é mergeado:
    - lê `stack_dir` e `environment` do body do PR
    - roda `go run ./cmd/brainctl apply --stack-dir <stack_dir>`

- `/.github/pull_request_template.md`
  - força o autor a declarar:
    - `stack_dir`
    - `environment`

## Pré-requisitos

1. Repositório no GitHub com Actions habilitado.
2. Ferramentas locais: Git e Go `1.22.x`.
3. Branch padrão `main`.
4. AWS e Infracost preparados para os workflows.

## Setup no GitHub (1 vez)

### 1) Branch protection na `main`

Em `Settings > Branches > Add rule`, habilite:
- Require a pull request before merging
- Require status checks to pass before merging
- Block force pushes
- (Opcional) Require approvals

### 2) Environments

Em `Settings > Environments`, crie:
- `dev`
- `staging`
- `prod`

Dica: para `prod`, configure reviewers obrigatórios antes de executar apply automático.

### 3) Secrets (repository ou environment)

Configure:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `INFRACOST_API_KEY`

Observação:
- `INFRACOST_API_KEY` é usado no PR para `brainctl cost`.
- Para `apply`, os obrigatórios são `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_REGION`.


## Onde informar `stack_dir` e `environment` (passo exato)

Você informa no **corpo do Pull Request** (campo *Description* no GitHub), usando o template `.github/pull_request_template.md`.

### Exemplo correto no body do PR

```
- stack_dir: stacks/ec2-app/dev
- environment: dev
```

Regras:
- `environment` deve ser: `dev`, `staging` ou `prod`.
- `stack_dir` deve começar com `stacks/` e existir no repositório.
- Não coloque apenas no título do PR, comentário ou commit — o workflow lê somente o **body** do PR.
- Comentário no PR **não** dispara esse workflow; editar o **body** dispara (evento `pull_request.edited`) e um novo commit também dispara.
- O CI de PR só roda se a branch de origem começar com `feat/`.

Dica: se o PR já existe, clique em **Edit** no PR e corrija a descrição; ao salvar, rode novamente o job falho.

## Como abrir PR com stack/ambiente corretos

Use o template e preencha a seção:

- stack_dir: `stacks/ec2-app/dev`
- environment: `dev`

Se não preencher, o workflow falha.

## Fluxo diário (branch -> PR -> merge)

1. Atualize sua `main` local:

```bash
git checkout main
git pull origin main
```

2. Crie branch:

```bash
git checkout -b feat/minha-mudanca
```

3. Faça mudanças e valide localmente:

```bash
gofmt -w .
go vet ./...
go test ./...
```

4. Commit e push (em branch `feat/...`):

```bash
git add .
git commit -m "feat: minha mudança"
git push -u origin feat/minha-mudanca
```

5. Abra PR para `main` e preencha `stack_dir` + `environment` no template.

6. Aguarde checks de PR:
- terraform preview (`plan` + `cost`)
- testes e checks Go

7. Após aprovação e merge, o `cd-v1.yml` roda `apply` automaticamente no stack do PR.

## Observações importantes

- Comece usando `environment: dev` para ganhar confiança.
- Só habilite fluxo equivalente para `prod` com approvals/reviewers no Environment.
- Se quiser mais segurança em v1.1, podemos adicionar:
  - gate manual antes do apply
  - `plan` e `apply` separados com aprovação explícita
  - controle por label (ex.: só aplica se PR tiver `safe-to-apply`)


## Destroy do ambiente dev (manual e automático)

Adicionamos o workflow `/.github/workflows/destroy-dev.yml` com dois modos:

1. **Manual** (`workflow_dispatch`)
   - Vá em **Actions > Destroy dev environment > Run workflow**
   - Preencha:
     - `stack_dir` (default: `stacks/ec2-app/dev`)
     - `confirm` = `DESTROY`
   - Executa: `go run ./cmd/brainctl destroy --stack-dir <stack_dir>`

2. **Automático por inatividade** (scheduler, 1x/hora)
   - Controlado por variables do repositório:
     - `AUTO_DESTROY_ENABLED` = `true|false`
     - `AUTO_DESTROY_AFTER_HOURS` = número de horas (ex.: `8`)
   - Regra inicial simples: se o repositório ficar sem novos commits por `X` horas, roda destroy do stack dev.

> Recomendação: começar só no manual. Depois ativar automático com `AUTO_DESTROY_ENABLED=true` quando o time estiver confortável.

---

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
