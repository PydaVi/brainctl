# CI/CD v1.0 do brainctl (simples, mas já orientado a Terraform)

Este guia implementa uma versão inicial para você entender o fluxo completo:
- branch -> PR
- preview de Terraform no PR (`plan` + `cost`)
- testes Go após preview
- `apply` automático depois do merge

## O que foi criado

- `/.github/workflows/ci.yml`
  - Em Pull Request para `main`:
    1. lê `stack_dir` e `environment` do body do PR
    2. roda:
       - `go run ./cmd/brainctl plan --stack-dir <stack_dir>`
       - `go run ./cmd/brainctl cost --stack-dir <stack_dir>`
    3. publica outputs (`plan-output.txt`, `cost-output.txt`) como artifact
    4. roda qualidade Go:
       - `gofmt` check
       - `go vet ./...`
       - `go test ./...`
  - Em push na `main`: roda os checks Go (`gofmt`, `go vet`, `go test`)

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

4. Commit e push:

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
