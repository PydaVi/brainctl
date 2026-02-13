# brainctl 🧠

> **Infraestrutura com mentalidade de produto**: do YAML para a AWS com governança, previsibilidade e velocidade.

O **brainctl** é uma CLI em Go criada para transformar provisionamento de infraestrutura em algo **escalável, padronizado e colaborativo**. Em vez de cada squad “reinventar Terraform”, o projeto centraliza padrões e acelera entregas com uma experiência simples: descrever a stack e executar.

---

### 🚀 Impacto real de negócio
- **Reduz atrito entre times de produto e plataforma** com um fluxo declarativo.
- **Acelera time-to-market** com operações de `plan` / `apply` padronizadas.
- **Aumenta previsibilidade** ao manter contrato de infraestrutura controlado por validações.

### 🧩 Engenharia com visão de escala
- Código em **Go** com organização modular (parser, generator, workspace, runner).
- Estratégia de stacks por ambiente (`dev`, `prod`) pronta para evolução.
- Uso de **Terraform** como engine de execução, preservando boas práticas de IaC.

### 🔐 Governança sem burocracia
- Sistema de **overrides com whitelist** para permitir customização segura.
- Flexibilidade para necessidades locais sem quebrar o baseline da plataforma.

---

## Como o brainctl funciona

```text
app.yaml (+ overrides.yaml) -> parser/validator (Go) -> generator (Go) -> Terraform workspace -> AWS
```

A proposta é simples: o time descreve “o que precisa”, e o brainctl cuida de gerar e orquestrar o caminho até a infraestrutura final.

## Arquitetura de blueprints (preparada para crescer)

O brainctl agora separa o **core da CLI** dos **blueprints de workload**:

- `internal/generator`: engine/roteador de geração
- `internal/blueprints/ec2app`: blueprint atual (`ec2-app`)

Isso permite evoluir para novos tipos de workload sem misturar regras de negócio em um único arquivo.

---

## Estrutura atual (preparada para crescer)

```text
stacks/
  dev/
    app.yaml
    overrides.yaml
  prod/
    app.yaml
    overrides.yaml
```

Esse modelo facilita padronização multiambiente e cria base para uma operação mais madura de platform engineering.

Cada stack também pode declarar o tipo de workload:

```yaml
workload:
  type: ec2-app
  version: v1
```

---


### User data em arquivo (app.yaml mais limpo)

Você pode apontar `ec2.user_data` e `db.user_data` para um arquivo `.ps1` usando:

```yaml
ec2:
  user_data_mode: merge
  user_data: file://scripts/app-user-data.ps1
```

- Caminhos relativos são resolvidos a partir de `--stack-dir`.
- Também funciona com caminho absoluto.
- Em modo `merge`, o brainctl normaliza wrappers `<powershell>` para evitar duplicação com o bootstrap de observabilidade.

---

## Comandos principais

```bash
go run ./cmd/brainctl plan   --stack-dir stacks/dev
go run ./cmd/brainctl apply  --stack-dir stacks/dev
go run ./cmd/brainctl status --stack-dir stacks/dev
go run ./cmd/brainctl blueprints
```

Também é possível desabilitar overrides quando necessário:

```bash
go run ./cmd/brainctl plan --stack-dir stacks/dev --overrides ""
```

---


### Catálogo de blueprints (PR 3)

A evolução para múltiplos workloads agora está formalizada com:

- `internal/blueprints/registry.go`: catálogo central com `type`, `version` e descrição
- `internal/generator/generator.go`: resolve blueprint por `workload.type` + `workload.version`
- `brainctl blueprints`: comando para listar blueprints disponíveis

Com isso, novos workloads entram como extensão de catálogo, sem acoplar regras no core da CLI.

---

### Acesso para diagnóstico (sem RDP)

Para facilitar troubleshooting quando o target group ficar unhealthy, o brainctl agora configura **SSM Session Manager** no profile das instâncias e pode criar endpoints privados de SSM (sem NAT), quando `observability.enable_ssm_endpoints=true`.


Exemplo no `app.yaml`:

```yaml
observability:
  enabled: true
  enable_ssm_endpoints: true
  enable_ssm_private_dns: false
```


> Se sua VPC tiver `enableDnsSupport` e `enableDnsHostnames` habilitados, você pode ativar também:

```yaml
observability:
  enable_ssm_private_dns: true
```

Fluxo recomendado de diagnóstico:

```bash
# 1) Descobrir IDs e dados de observabilidade
go run ./cmd/brainctl status --stack-dir stacks/dev

# 2) Iniciar sessão na instância APP (substitua INSTANCE_ID)
aws ssm start-session --target INSTANCE_ID
```

Checks úteis dentro da instância:

```powershell
Get-WindowsFeature Web-Server
Get-Service W3SVC
Get-Content C:\ProgramData\Amazon\EC2Launch\log\agent.log -Tail 200
Get-Content C:\inetpub\wwwroot\index.html -Head 40
```

---

## Overrides suportados no MVP

`overrides.yaml` é opcional e permite ajustes controlados sem comprometer o contrato principal.

Paths atualmente suportados (somente Security Groups):
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

## Narrativa profissional (pronta para portfólio)

Se você quiser usar esse projeto como case, aqui vai um resumo em tom de currículo/LinkedIn:

> “Desenvolvi o **brainctl**, uma CLI em Go para padronização de infraestrutura AWS com abordagem declarativa e integração com Terraform. O projeto melhora governança de ambientes, acelera provisionamento e reduz inconsistências entre stacks, habilitando uma operação mais eficiente de platform engineering.”

---

## Próximos passos estratégicos

- Expandir catálogo de recursos suportados além de EC2-centric workloads.
- Adicionar testes de contrato para schemas de `app.yaml` e `overrides.yaml`.
- Evoluir observabilidade do ciclo de provisionamento (logs estruturados e métricas).
- Publicar release versionada para distribuição em times internos.

---

## Resumo

O **brainctl** não é só uma ferramenta de automação: é um passo concreto para tratar infraestrutura como produto — com **padrão, escala e experiência de uso**.

---

## Sprint 2: Recovery com restore completo + DR drill mensal

O bloco `recovery` agora suporta **DR drill mensal** além de snapshots e runbooks.

Exemplo:

```yaml
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

Guardrails de validação para `recovery.drill.enabled=true`:
- `recovery.enabled=true`
- `recovery.enable_runbooks=true`
- `recovery.backup_app=true`
- `observability.enabled=true`
- `lb.enabled=true` quando `register_to_target_group=true`

Novo output: `recovery_drill_schedule_name`.
