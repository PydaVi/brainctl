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