# CI/CD Terraform (GitHub Actions)

Este repositório usa dois workflows para validar e aplicar infraestrutura Terraform gerada pelo `brainctl`.

## Workflows

### 1) `.github/workflows/terraform-plan.yml`

**Trigger:** `pull_request` para `main` (somente branches `feature/*` e `fix/*`).

Fluxo executado por stack em `./stacks/*` (onde existir `app.yaml`):

1. `go run ./cmd/brainctl render --stack-dir <stack>` (gera o workspace Terraform)
2. `terraform fmt -check -recursive`
3. `terraform init`
4. `terraform validate`
5. `terraform plan`

Saídas do plan:

- Comentário no PR (com upsert usando marcador `<!-- brainctl-terraform-plan -->`, sem spam de comentários).
- Artifact `terraform-plan-output` com o log completo.

Permissões mínimas usadas no workflow de plan:

- `contents: read`
- `pull-requests: write`

### 2) `.github/workflows/terraform-apply.yml`

**Trigger:** `push` para `main` (não roda em PR).

Fluxo por stack em `./stacks/*` (com `app.yaml`):

1. `go run ./cmd/brainctl apply --stack-dir <stack> --auto-approve`

Esse apply roda com o **merge commit exato** que chegou em `main` (checkout do SHA do evento `push`).

Boas práticas aplicadas:

- Apply serializado por `concurrency: terraform-apply-main` para evitar corridas.
- Sem `pull-requests: write` no apply.

## Autenticação AWS via Repository Secrets

Ambos workflows usam `aws-actions/configure-aws-credentials` com credenciais estáticas armazenadas no GitHub Secrets.

## Secrets necessários no repositório

Configure em **Settings → Secrets and variables → Actions**:

- `AWS_ACCESS_KEY_ID` (obrigatório)
- `AWS_SECRET_ACCESS_KEY` (obrigatório)
- `AWS_REGION` (obrigatório; ex.: `us-east-1`)

## Observações

- O plan falha se `terraform fmt -check` ou `terraform validate` falharem.
- Se novos stacks forem adicionados em `stacks/<novo>/app.yaml`, eles entram automaticamente no fluxo.
