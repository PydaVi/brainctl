# brainctl 🧠

> Infraestrutura com mentalidade de produto
> Transformando YAML declarativo em infraestrutura AWS governada, previsível e escalável.

---

## 🌎 O Problema

Equipes que adotam Infrastructure as Code geralmente enfrentam desafios recorrentes:

* Times diferentes criam stacks com padrões inconsistentes
* Governança e segurança dependem de revisão manual
* Crescimento da cloud gera ambientes snowflake
* Onboarding de novos engineers é lento
* ClickOps continua existindo paralelamente ao IaC
* Terraform puro exige conhecimento profundo para tarefas comuns

Conforme ambientes crescem, o problema deixa de ser **provisionar recursos** e passa a ser **padronizar, governar e escalar infraestrutura com segurança e velocidade**.

---

## 💡 A Solução

O **brainctl** é uma CLI de Platform Engineering que cria uma camada de abstração sobre Terraform, permitindo que equipes descrevam workloads usando contratos declarativos simples e governados.

Ele transforma definições YAML em infraestrutura AWS padronizada, aplicando automaticamente:

* Baselines de segurança
* Padrões arquiteturais
* Governança de recursos
* Estrutura multiambiente
* Integração com práticas modernas de IaC

---

## 🧭 Posicionamento do BrainCTL

| Camada    | Responsabilidade                              |
| --------- | --------------------------------------------- |
| Terraform | Provisionamento de recursos                   |
| brainctl  | Padronização, governança e experiência de uso |

O brainctl **não substitui Terraform**.
Ele atua como uma plataforma que organiza e controla como Terraform é utilizado.

---

## 🎯 Quem se beneficia

* Platform teams
* Times migrando de ClickOps para IaC
* Empresas que precisam escalar governança cloud
* Organizações com múltiplos squads provisionando recursos
* Ambientes híbridos e multi-conta AWS

---

## 🚀 Impacto de Negócio

* Reduz atrito entre times
* Acelera time-to-market
* Aumenta previsibilidade operacional
* Melhora postura de segurança
* Padroniza provisionamento cloud
* Reduz risco de configuração incorreta

---

## ⚙️ Como Funciona

```
app.yaml (+ overrides.yaml)
        ↓
Parser / Validator (Go)
        ↓
Blueprint Generator
        ↓
Terraform Workspace
        ↓
AWS Infrastructure
```

A equipe descreve **o que precisa**.
O brainctl gerencia **como isso será provisionado**.

---

## 📦 Exemplo de Uso

### app.yaml

```yaml
app:
  name: payments-api
  environment: dev
  region: us-east-1

workload:
  type: ec2-app
  version: v1

ec2:
  instance_type: t3.micro
  os: windows-2022
```

---

### overrides.yaml (Opcional)

Permite customização controlada sem quebrar o baseline.

```yaml
overrides:
  - op: append
    path: security_groups.app.ingress
    value:
      description: "Office RDP"
      from_port: 3389
      to_port: 3389
      protocol: tcp
      cidr_blocks:
        - "177.10.10.0/24"
```

---

## 📁 Estrutura de Stacks

```
stacks/
  dev/
    app.yaml
    overrides.yaml
  prod/
    app.yaml
    overrides.yaml
```

---

## 🧩 Arquitetura do Projeto

### Core CLI

Responsável por orquestração, validação e execução.

### Blueprint Engine

Define como workloads são transformados em infraestrutura.

### Terraform Runner

Executa provisionamento mantendo compatibilidade com práticas padrão do mercado.

---

## 🏗 Arquitetura de Blueprints

O brainctl separa:

* Core da plataforma
* Catálogo extensível de workloads

```
internal/
  generator/
  blueprints/
    ec2app/
    registry.go
```

Isso permite adicionar novos workloads sem modificar o core.

---

## 📚 Catálogo de Blueprints

O sistema suporta múltiplos tipos e versões:

```bash
brainctl blueprints
```

Cada blueprint define:

* Recursos suportados
* Baselines de segurança
* Estrutura arquitetural
* Versionamento do contrato

---

## 🔐 Governança com Flexibilidade

O brainctl implementa um modelo híbrido:

* Contrato principal governado
* Overrides com whitelist controlada
* Customização segura sem perda de padrão

---

## 🧪 Design Decisions

### CLI em Go

Portabilidade, performance e facilidade de distribuição.

### Terraform como Engine

Evita reinventar o provisionamento e mantém compatibilidade com ecossistema IaC.

### Blueprint Registry

Permite extensibilidade desacoplada.

### Overrides Whitelist

Equilibra governança e flexibilidade.

---

## 📌 Comandos Principais

```bash
brainctl plan   --stack-dir stacks/dev
brainctl apply  --stack-dir stacks/dev
brainctl status --stack-dir stacks/dev
brainctl blueprints
```

---

## ⚠️ Limitações Atuais

* Catálogo inicial focado em workloads EC2
* Suporte inicial AWS-only
* Policy-as-Code ainda em evolução
* Interface CLI (portal self-service planejado)

---

## 🗺 Roadmap

### Curto Prazo

* Testes de contrato para schemas
* Observabilidade do ciclo de provisionamento
* Versionamento formal de blueprints
* Pipeline CI/CD integrado

### Médio Prazo

* Expansão do catálogo de workloads
* Policy-as-Code integrado
* Suporte multi-conta AWS
* Plugin model para blueprints

### Longo Prazo

* Portal self-service para squads
* Multi-cloud support
* Integração com plataformas DevEx
* Possível oferta SaaS ou modelo consultivo

---

## 🌐 Casos de Uso Reais

* Padronização de workloads corporativos
* Criação de plataformas internas de infraestrutura
* Aceleração de migração para IaC
* Baseline de segurança para provisionamento cloud

---

## 🧠 Filosofia do Projeto

O brainctl trata infraestrutura como produto, aplicando conceitos de:

* Platform Engineering
* Developer Experience
* Governance by Design
* Security by Default
* Infrastructure Contracts

---

## 💼 Possibilidades de Uso Comercial

O brainctl pode ser utilizado como:

* Plataforma interna corporativa
* Ferramenta open source de padronização cloud
* Base para consultorias de Platform Engineering
* Framework para construção de plataformas DevEx

---

## 👨‍💻 Sobre o Autor

O brainctl nasceu da experiência prática em ambientes corporativos híbridos e cloud-native, observando desafios reais de escalabilidade, governança e segurança em infraestrutura moderna.

---

## 📜 Licença

MIT License

---

## 🤝 Contribuição

Contribuições são bem-vindas.

Roadmap e propostas podem ser abertas via Issues.

---

## ⭐ Visão Final

O brainctl não é apenas automação.

É uma tentativa de transformar infraestrutura em uma plataforma governada, escalável e acessível.