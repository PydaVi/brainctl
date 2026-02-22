# Blueprint `ec2-app`

## English

### 1. Scope

`ec2-app` provisions an EC2-based application environment with optional database, load balancing, autoscaling, observability, and recovery resources.

### 2. Main topology

- App EC2 instance (or ASG when autoscaling is enabled)
- Optional DB EC2 instance
- Security groups (`app`, `db`, `alb`)
- Optional Application Load Balancer
- Optional CloudWatch dashboards/alarms + SNS notifications
- Optional recovery resources (snapshot policies, SSM automation, DR drill)

### 3. Contract (`app.yaml`) example

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

autoscaling:
  enabled: false

observability:
  enabled: true

recovery:
  enabled: true
```

### 4. Guardrails

- Autoscaling without load balancer is blocked.
- Recovery options validate required dependencies.
- SG custom rules are limited by SG type (`app`, `db`, `alb`).

### 5. CLI operations

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

### 6. Reference paths

- `stacks/ec2-app/dev/app.yaml`
- `stacks/ec2-app/prod/app.yaml`
- `stacks/ec2-app/*/security-groups/*.yaml`
- `stacks/ec2-app/*/scripts/app-user-data.ps1`

---

## Português

### 1. Escopo

`ec2-app` provisiona um ambiente de aplicação em EC2 com banco opcional, balanceamento de carga, autoscaling, observabilidade e recursos de recovery opcionais.

### 2. Topologia principal

- Instância EC2 de aplicação (ou ASG quando autoscaling estiver habilitado)
- Instância EC2 de banco opcional
- Security groups (`app`, `db`, `alb`)
- Application Load Balancer opcional
- Dashboards/alarmes CloudWatch + notificações SNS opcionais
- Recursos de recovery opcionais (snapshots, automações SSM, DR drill)

### 3. Exemplo de contrato (`app.yaml`)

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

autoscaling:
  enabled: false

observability:
  enabled: true

recovery:
  enabled: true
```

### 4. Guardrails

- Autoscaling sem load balancer é bloqueado.
- Opções de recovery validam dependências obrigatórias.
- Regras customizadas de SG ficam limitadas ao tipo (`app`, `db`, `alb`).

### 5. Operações via CLI

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

### 6. Caminhos de referência

- `stacks/ec2-app/dev/app.yaml`
- `stacks/ec2-app/prod/app.yaml`
- `stacks/ec2-app/*/security-groups/*.yaml`
- `stacks/ec2-app/*/scripts/app-user-data.ps1`
