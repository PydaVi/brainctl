# brainctl 🧠

`brainctl` é uma CLI em Go para provisionar workloads padronizados na AWS com base em YAML declarativo.

> MVP atual: foco em provisionamento base, observabilidade e escala da camada APP com Auto Scaling Group.

## Arquitetura de diretórios (preparada para crescer)

Mesmo usando uma única stack por enquanto, a estrutura recomendada já separa por ambiente:

```text
stacks/
  dev/
    app.yaml
    overrides.yaml
  prod/
    app.yaml
    overrides.yaml
```

Com isso, o comando passa a usar `--stack-dir`:

```bash
go run ./cmd/brainctl plan --stack-dir stacks/dev
```

Se quiser manter o modo antigo, ainda funciona com `-f app.yaml`.

## Override controlado (whitelist)

`overrides.yaml` é opcional e permite customizações sem quebrar o contrato principal.

Paths suportados no MVP (somente Security Groups):
- `security_groups.app.ingress` (`append`)
- `security_groups.db.ingress` (`append`)
- `security_groups.alb.ingress` (`append`)

Exemplo (append nos SGs de APP, DB e ALB):

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

  - op: append
    path: security_groups.db.ingress
    value:
      description: "DB from BI VPN"
      from_port: 1433
      to_port: 1433
      protocol: tcp
      cidr_blocks:
        - "10.100.0.0/16"

  - op: append
    path: security_groups.alb.ingress
    value:
      description: "ALB from corporate proxy"
      from_port: 80
      to_port: 80
      protocol: tcp
      cidr_blocks:
        - "200.200.10.0/24"
```

## AMI custom e User Data (MVP funcional)

Agora APP e DB aceitam AMI custom opcional com fallback para Windows Server 2022 quando vazio.

Campos:
- `ec2.ami`, `db.ami`: AMI custom opcional.
- `ec2.user_data_mode`, `db.user_data_mode`: `default | custom | merge`.
- `ec2.user_data`, `db.user_data`: script custom (PowerShell/Bash), conforme SO da AMI.

Regras de modo:
- `default`: usa somente o user data padrão do brainctl.
- `custom`: usa somente o user data informado no YAML.
- `merge`: concatena o padrão + custom.

No exemplo oficial em `stacks/dev/app.yaml`, a APP está com `user_data_mode: merge` e script PowerShell para instalar IIS e publicar um `hello world` em `/` (útil para validar health check do ALB).

## Recovery mode (snapshots + runbooks)

O bloco `recovery` ativa um modo opcional de recuperação com:
- snapshots diários automáticos de volumes EBS da APP e DB (via DLM)
- retenção por dias
- runbooks SSM Automation para localizar o snapshot mais recente e criar volume EBS de recuperação por camada

Exemplo:

```yaml
recovery:
  enabled: true
  snapshot_time_utc: "03:00"
  retention_days: 7
  backup_app: true
  backup_db: true
  enable_runbooks: true
```

Campos:
- `enabled`: liga/desliga o modo de recuperação
- `snapshot_time_utc`: horário diário UTC (`HH:MM`)
- `retention_days`: quantos dias (snapshots diários) manter
- `backup_app`: snapshot para APP
- `backup_db`: snapshot para DB (requer `db.enabled: true`)
- `enable_runbooks`: cria runbooks SSM de recuperação


Execução de runbook (exemplo APP):

```bash
aws ssm start-automation-execution \
  --document-name <app>-<env>-recovery-app \
  --parameters AvailabilityZone=us-east-1a,VolumeType=gp3
```

## Fluxo

```text
app.yaml (+ overrides.yaml) -> parser/validator (Go) -> generator (Go) -> Terraform workspace -> AWS
```

## Comandos

```bash
go run ./cmd/brainctl plan   --stack-dir stacks/dev
go run ./cmd/brainctl apply  --stack-dir stacks/dev
go run ./cmd/brainctl status --stack-dir stacks/dev
```

Se quiser desabilitar overrides:

```bash
go run ./cmd/brainctl plan --stack-dir stacks/dev --overrides ""
```
