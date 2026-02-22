# brainctl 🧠

## English

Infrastructure as contract, not improvisation.

`brainctl` is a CLI that reads a declarative stack contract (`app.yaml` + optional `security-groups/*.yaml`), validates guardrails, and generates structured Terraform for AWS workloads.

### Current supported blueprints

- **ec2-app**: EC2 application workload with optional database, ALB/ASG options, observability, and recovery.
- **k8s-workers**: self-managed Kubernetes lab on EC2 with kubeadm (control-plane + workers).

Technical docs:
- `docs/blueprints/ec2-app.md`
- `docs/blueprints/kubernetes-workers.md`
- `docs/cicd-v1.md`

### Core flow

```text
app.yaml (+ security-groups/*.yaml)
        ↓
validation + guardrails
        ↓
structured Terraform generation
        ↓
aws provisioning
        ↓
operation-ready environment
```

### Repository structure

```text
cmd/brainctl                     # CLI entrypoint
internal/config                  # parser, defaults, validations
internal/generator               # terraform workspace generation
internal/blueprints/ec2app       # ec2-app blueprint generator
internal/blueprints/k8sworkers   # k8s-workers blueprint generator
internal/terraform               # terraform command wrapper
internal/workspace               # execution directory setup
terraform-modulesec2-app         # base terraform module (ec2-app)
terraform-modulesk8s-workers     # terraform module (k8s-workers)
stacks/ec2-app/dev|prod          # ec2-app contracts
stacks/k8s-workers/dev|prod      # k8s-workers contracts
```

### CLI usage

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

### Example contract

```yaml
workload:
  type: ec2-app
  version: v1

terraform:
  backend:
    bucket: "your-terraform-state-bucket"
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

---

## Português

Infraestrutura como contrato, não como improviso.

O `brainctl` é uma CLI que lê um contrato declarativo de stack (`app.yaml` + `security-groups/*.yaml` opcionais), valida guardrails e gera Terraform estruturado para workloads AWS.

### Blueprints suportados atualmente

- **ec2-app**: workload de aplicação em EC2 com banco opcional, opções de ALB/ASG, observabilidade e recovery.
- **k8s-workers**: laboratório Kubernetes self-managed em EC2 com kubeadm (control-plane + workers).

Documentação técnica:
- `docs/blueprints/ec2-app.md`
- `docs/blueprints/kubernetes-workers.md`
- `docs/cicd-v1.md`

### Fluxo central

```text
app.yaml (+ security-groups/*.yaml)
        ↓
validação + guardrails
        ↓
geração estruturada de Terraform
        ↓
provisionamento aws
        ↓
ambiente preparado para operação
```

### Estrutura do repositório

```text
cmd/brainctl                     # entrada da CLI
internal/config                  # parser, defaults, validações
internal/generator               # geração do workspace Terraform
internal/blueprints/ec2app       # gerador do blueprint ec2-app
internal/blueprints/k8sworkers   # gerador do blueprint k8s-workers
internal/terraform               # wrapper de comandos Terraform
internal/workspace               # preparação do diretório de execução
terraform-modulesec2-app         # módulo Terraform base (ec2-app)
terraform-modulesk8s-workers     # módulo Terraform (k8s-workers)
stacks/ec2-app/dev|prod          # contratos do ec2-app
stacks/k8s-workers/dev|prod      # contratos do k8s-workers
```

### Uso da CLI

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

### Exemplo de contrato

```yaml
workload:
  type: ec2-app
  version: v1

terraform:
  backend:
    bucket: "seu-bucket-de-state"
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
