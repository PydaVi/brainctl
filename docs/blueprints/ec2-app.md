# Blueprint `ec2-app`

## 1. Escopo

O blueprint `ec2-app` provisiona uma aplicação em EC2 com componentes opcionais de balanceamento, auto scaling, observabilidade e recuperação.

A geração é orientada por contrato (`app.yaml`) e produz um workspace Terraform com módulos versionados do repositório.

## 2. Componentes provisionáveis

### 2.1 Fundação

- VPC e subnets são referenciadas por ID no contrato (não criadas pelo blueprint).
- Security Groups para aplicação, banco e ALB (quando habilitado).

### 2.2 Camada de aplicação

- EC2 de aplicação (single instance) ou Auto Scaling Group (quando `app_scaling.enabled: true`).
- IAM Instance Profile para operação com SSM/observabilidade.
- bootstrap por `user_data` (inline ou `file://`, conforme modo configurado).

### 2.3 Camada de banco (opcional)

`db.enabled: true` habilita banco em um dos modos:

- instância EC2 para banco (modo self-managed), ou
- RDS (`db.mode: rds`) com parâmetros de engine/classe/storage.

### 2.4 Balanceamento (opcional)

`lb.enabled: true` habilita:

- Application Load Balancer.
- listener e target group.
- regras de acesso por CIDR configurável.

### 2.5 Auto scaling (opcional)

`app_scaling.enabled: true` habilita:

- Launch Template.
- Auto Scaling Group.
- política de scaling por alvo de CPU.

Guardrail aplicado: Auto Scaling exige Load Balancer habilitado.

### 2.6 Observabilidade (opcional)

`observability.enabled: true` habilita:

- dashboards CloudWatch.
- alarmes e notificações SNS.
- integração operacional com SSM.
- endpoints privados para serviços de observabilidade/SSM conforme configuração.

### 2.7 Recovery (opcional)

`recovery.enabled: true` habilita:

- snapshots agendados.
- runbooks de recuperação.
- parâmetros para DR drill e retenção de backups.

## 3. Contrato de configuração (`app.yaml`)

Exemplo técnico mínimo com recursos opcionais habilitados:

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
  name: brain-app
  environment: dev
  region: us-east-1

infrastructure:
  vpc_id: vpc-xxxxxxxx
  subnet_id: subnet-xxxxxxxx

ec2:
  instance_type: t3.micro
  os: windows
  ami: ""
  user_data_mode: merge
  user_data: file://scripts/app-user-data.ps1

lb:
  enabled: true
  scheme: internet-facing
  subnet_ids: ["subnet-a", "subnet-b"]
  listener_port: 80
  target_port: 8080
  allowed_cidr: 0.0.0.0/0

app_scaling:
  enabled: true
  subnet_ids: ["subnet-a", "subnet-b"]
  min_size: 1
  max_size: 3
  desired_capacity: 1
  cpu_target: 60

observability:
  enabled: true
  cpu_high_threshold: 80
  alert_email: ops@example.com

recovery:
  enabled: true
  snapshot_time_utc: "03:00"
  retention_days: 7
```

## 4. User data e estratégia de merge

Campos relevantes:

- `ec2.user_data_mode`
  - `default`: usa apenas user data padrão do blueprint.
  - `custom`: usa apenas user data informado no contrato.
  - `merge`: concatena user data padrão + custom.

- `ec2.user_data`
  - conteúdo inline, ou
  - referência externa via `file://caminho/arquivo`.

O mesmo padrão pode ser aplicado para bloco de banco quando houver user data específico para DB EC2.

## 4.1 Backend Terraform

O backend remoto é definido no contrato via `terraform.backend`:

- `bucket`: bucket S3 de state remoto.
- `key_prefix`: prefixo para isolar estados por time/empresa (a key final inclui app e ambiente).
- `region`: região do bucket de state.
- `use_lockfile`: habilita lock de state no backend S3.

## 5. Guardrails principais

- Auto Scaling sem Load Balancer é bloqueado na validação.
- Operações de recovery validam pré-requisitos de recursos dependentes.
- Regras extras de Security Group são lidas de arquivos em `security-groups/` por tipo de SG (`app`, `db`, `alb`).

## 6. Outputs esperados

Dependendo da combinação de recursos, os outputs incluem:

- IDs e IPs de instâncias.
- DNS do ALB.
- nome do ASG.
- referências de observabilidade (dashboards/alarmes).
- artefatos e comandos relacionados a recovery.

## 7. Operação via CLI

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

## 8. Diretórios de referência

- contrato base: `stacks/ec2-app/dev/app.yaml`
- contrato de produção: `stacks/ec2-app/prod/app.yaml`
- regras de SG: `stacks/ec2-app/*/security-groups/*.yaml`
- script de bootstrap exemplo: `stacks/ec2-app/*/scripts/app-user-data.ps1`
