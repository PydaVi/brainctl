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
```

---

## Comandos principais

```bash
go run ./cmd/brainctl plan   --stack-dir stacks/dev
go run ./cmd/brainctl apply  --stack-dir stacks/dev
go run ./cmd/brainctl status --stack-dir stacks/dev
```

Também é possível desabilitar overrides quando necessário:

```bash
go run ./cmd/brainctl plan --stack-dir stacks/dev --overrides ""
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
