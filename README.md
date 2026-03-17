# brainctl

> Original Portuguese version: [README.pt.md](README.pt.md)

## What is brainctl

**brainctl** is a Go CLI that lets teams describe AWS infrastructure through a simple `app.yaml` contract.
It exists to help teams without Terraform maturity deploy consistent, secure, observable workloads from day one.

## What changed in v2

| Component | v1 | v2 |
|---|---|---|
| Orchestration | Go-generated Terraform | Terragrunt workspace + Terraform modules |
| Backend config | `backend {}` blocks per module | `remote_state` in `terragrunt.hcl` |
| Dependencies | Manual/sequential | Terragrunt dependency graph |
| CI/CD auth | Static AWS keys | OIDC (ephemeral credentials) |
| Security scan | None | `tfsec` + `trivy` in PR |
| Prod apply | Auto | Manual approval required |

## Stack

- Go + Cobra (CLI)
- Terragrunt (orchestration)
- Terraform (modules)
- AWS
- GitHub Actions (CI/CD)

## How it works

```text
app.yaml (team contract)
        ↓
brainctl CLI
        ↓ generates
.brainctl-workspace/<app>-<env>/terragrunt.hcl
        ↓ executes
Terragrunt
        ↓ calls
Terraform modules (modules/)
        ↓
AWS
```

## Usage

### Prerequisites

- Go 1.22+
- Terragrunt in PATH
- Terraform in PATH
- AWS credentials (local) or OIDC (CI/CD)

### Main commands

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

## Repository structure

```text
cmd/brainctl/                # CLI entrypoint
internal/cli/                # cobra commands
internal/config/             # app.yaml parser and validation
internal/generator/          # terragrunt workspace generation
internal/terragrunt/         # terragrunt runner
internal/blueprints/         # workload blueprints
modules/                     # Terraform modules (ec2-app, k8s-workers, shared)
stacks/                      # declarative contracts per workload/env
docs/adr/                    # architecture decision records
.github/workflows/           # CI/CD pipelines
```

## Contract example

```yaml
workload:
  type: ec2-app
  version: v1

terraform:
  backend:
    bucket: "your-state-bucket"
    key_prefix: "brainctl"
    region: "us-east-1"
    use_lockfile: true

app:
  name: brain-test
  environment: dev
  region: us-east-1

ec2:
  instance_type: t3.micro

lb:
  enabled: true

observability:
  enabled: true

recovery:
  enabled: true
```

## Guardrails (examples)

- Auto Scaling is blocked without a Load Balancer.
- Recovery drills validate dependent prerequisites (observability, backup flags).
- Extra SG rules are loaded from `security-groups/` by type (`app`, `db`, `alb`).

## Contributing a new blueprint

1. Add a Terraform module under `modules/<blueprint>/`.
2. Add a blueprint generator in `internal/blueprints/` to map `AppConfig` → inputs.
3. Register the blueprint in `internal/blueprints/registry.go`.
4. Add example contracts under `stacks/<blueprint>/`.
5. Document the blueprint in `docs/blueprints/`.
