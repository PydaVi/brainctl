# brainctl 🧠

O **brainctl** é uma plataforma de provisionamento de infraestrutura pensada para transformar operação em vantagem competitiva.
Em vez de cada time técnico montar sua própria automação, a empresa define um padrão simples em YAML e executa com previsibilidade.

---

## 1) Visão para negócio (sem jargão)

### O problema que o brainctl resolve
Empresas perdem tempo e dinheiro quando cada ambiente (dev, homologação, produção) nasce de um jeito diferente.
Isso gera:
- atrasos em entregas;
- risco de incidentes por configuração inconsistente;
- dificuldade de auditoria e governança;
- dependência de poucas pessoas para operar infraestrutura.

### O que o brainctl entrega
Com o brainctl, a infraestrutura passa a ter **modelo de produto**:
- **Padronização**: ambientes seguem o mesmo contrato;
- **Velocidade**: criação e atualização por comandos simples;
- **Segurança operacional**: validações evitam combinações perigosas;
- **Escalabilidade organizacional**: times conseguem evoluir sem reinventar a base.

### Resultado esperado para a empresa
- menor tempo entre ideia e ambiente pronto;
- redução de retrabalho operacional;
- melhor previsibilidade para roadmap;
- base robusta para crescimento com compliance.

---

## 2) Como funciona (resumo executivo)

```text
app.yaml (+ overrides.yaml) -> validação e guardrails -> geração Terraform -> aplicação na AWS
```

Você descreve o que precisa; o brainctl transforma isso em infraestrutura pronta, com padrões de governança e observabilidade embutidos.

---

## 3) Guia técnico completo

## 3.1 Arquitetura do projeto

```text
cmd/brainctl                # entrada da CLI
internal/config             # parser, defaults e validações de contrato
internal/generator          # orquestra geração do workspace
internal/blueprints/ec2app  # blueprint ec2-app (template de Terraform gerado)
internal/terraform          # wrapper de comandos terraform (init/plan/apply/destroy/output)
internal/workspace          # preparo do diretório de execução
terraform-modulesec2-app    # módulo Terraform base (app/db/lb/asg/observability/recovery)
stacks/dev|prod             # contratos por ambiente (app.yaml + scripts)
```

---

## 3.2 Funcionalidades que o brainctl já suporta

### A) Provisionamento base EC2
- Instância de aplicação;
- Camada de banco opcional com modo `ec2` (legado) ou `rds`;
- Security Groups padrão e regras extras via override controlado.

### B) Load Balancer e escalabilidade
- ALB público ou privado;
- target group + listener;
- Auto Scaling Group para camada APP com política por CPU.

### C) Observabilidade operacional
- dashboards e alarmes de CloudWatch (incluindo painel/alarmes para RDS quando `db.mode=rds`);
- endpoints privados para SSM + CloudWatch (`ssm`, `ssmmessages`, `ec2messages`, `logs`, `monitoring`) em subnets privadas;
- SNS para alertas por e-mail;
- suporte a Session Manager e endpoints privados de SSM.

### D) Recovery (Sprint 2)
- snapshots diários via DLM;
- runbooks de recuperação;
- **restore completo da APP** (cria volume restaurado, sobe instância de recuperação e anexa volume);
- **restore completo da DB em modo EC2** (mesmo fluxo de volume + instância + attach para plano de continuidade);
- **DR drill mensal** com EventBridge Scheduler disparando automação SSM.

---

## 3.3 Contrato YAML (workload ec2-app)

Exemplo simplificado:

```yaml
workload:
  type: ec2-app
  version: v1

app:
  name: brain-test
  environment: dev
  region: us-east-1

infrastructure:
  vpc_id: vpc-xxxx
  subnet_id: subnet-xxxx
  subnet_ids:
    - subnet-a
    - subnet-b

ec2:
  instance_type: t3.micro
  ami: ""
  user_data_mode: merge
  user_data: file://scripts/app-user-data.ps1
  imds_v2_required: true

db:
  enabled: true
  mode: ec2 # ec2 | rds
  instance_type: t3.micro
  port: 1433
  rds:
    instance_class: db.t3.micro
    engine: postgres
    engine_version: "16.3"
    allocated_storage: 20
    storage_type: gp3
    multi_az: false
    db_name: appdb
    username: brainctl
    password: "troque-esta-senha"
    backup_retention_days: 7
    publicly_accessible: false

lb:
  enabled: true
  scheme: public
  subnet_ids: [subnet-a, subnet-b]
  listener_port: 80
  target_port: 80
  instance_count: 1

app_scaling:
  enabled: true
  subnet_ids: [subnet-a, subnet-b]
  min_size: 2
  max_size: 4
  desired_capacity: 2
  cpu_target: 60

observability:
  enabled: true
  enable_private_endpoints: true
  enable_ssm_endpoints: true
  endpoint_subnet_ids:
    - subnet-a
    - subnet-b
  enable_ssm_private_dns: true
  cpu_high_threshold: 80
  alert_email: "time@empresa.com"

recovery:
  enabled: true
  snapshot_time_utc: "03:00"
  retention_days: 7
  backup_app: true
  backup_db: true
  enable_runbooks: true
  drill:
    enabled: true
    schedule_expression: "cron(0 3 1 * ? *)"
    register_to_target_group: false
```

---

## 3.4 Guardrails importantes

Algumas regras aplicadas automaticamente:
- `app_scaling.enabled=true` exige `lb.enabled=true`;
- `lb.instance_count` só vale para modo sem ASG (deve ser `1` quando `app_scaling.enabled=true`);
- `lb.instance_count>1` exige `lb.enabled=true`;
- `recovery.backup_db=true` exige `db.enabled=true`;
- `recovery.backup_db=true` exige `db.mode=ec2` (backup de DB via snapshot EBS);
- `db.mode=rds` exige `db.rds.password`;
- `recovery.drill.enabled=true` exige:
  - `recovery.enabled=true`
  - `recovery.enable_runbooks=true`
  - `recovery.backup_app=true`
  - `observability.enabled=true`
  - `lb.enabled=true` quando `recovery.drill.register_to_target_group=true`

Esses guardrails evitam cenários que “passam no deploy”, mas quebram em produção.

---

## 3.5 Comandos da CLI

```bash
go run ./cmd/brainctl plan   --stack-dir stacks/dev
go run ./cmd/brainctl apply  --stack-dir stacks/dev
go run ./cmd/brainctl destroy --stack-dir stacks/dev
go run ./cmd/brainctl status --stack-dir stacks/dev
go run ./cmd/brainctl output --stack-dir stacks/dev
go run ./cmd/brainctl blueprints
```

Também é possível ignorar overrides:

```bash
go run ./cmd/brainctl plan --stack-dir stacks/dev --overrides ""
```

---

## 3.6 User Data por arquivo

Para manter `app.yaml` limpo, use:

```yaml
ec2:
  user_data_mode: merge
  user_data: file://scripts/app-user-data.ps1
```

Suporta caminho relativo ao `--stack-dir` e caminho absoluto.

---

## 3.7 Overrides suportados (whitelist)

- `security_groups.app.ingress` (`append`)
- `security_groups.db.ingress` (`append`)
- `security_groups.alb.ingress` (`append`)

Exemplo:

```yaml
overrides:
  - op: append
    path: security_groups.app.ingress
    value:
      description: "RDP Office"
      from_port: 3389
      to_port: 3389
      protocol: tcp
      cidr_blocks:
        - "177.10.10.0/24"
```

---

## 3.8 Outputs relevantes

Exemplos úteis retornados pelo Terraform:
- `instance_id`, `private_ip`, `public_ip`
- `app_asg_name`, `app_asg_min_size`, `app_asg_max_size`
- `alb_dns_name`, `alb_target_group_arn`
- `observability_app_dashboard_url`
- `recovery_app_runbook_name`, `recovery_db_runbook_name`
- `recovery_drill_schedule_name`

---

## 4) Posicionamento estratégico

O brainctl é uma base para plataforma interna: menos esforço repetitivo, mais foco em produto e crescimento sustentável.

Se quiser, no próximo passo eu já posso montar um **guia de operação diário** (runbook de uso do time) com fluxo de incidentes, recovery e checklist de go-live.
