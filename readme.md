# brainctl 🧠

Infraestrutura como contrato, não como improviso

---

## Sobre o projeto

O **brainctl** é um projeto que nasceu de experiências reais trabalhando com infraestrutura corporativa em crescimento.
Ele não tenta reinventar o Terraform nem substituir ferramentas existentes. A ideia é mais simples: estudar formas de ajudar times a padronizar infraestrutura, reduzir erros operacionais e aplicar segurança e observabilidade desde o início, sem precisar que todos fossem especialistas em terraform e gestão de IAC.

Esse projeto também representa meu aprofundamento nos estudos de **Engenharia de Plataforma**, **Cloud Security** e **automação de infraestrutura orientada a produto**.

---

## Contexto e motivação

Em muitos ambientes corporativos, principalmente com workloads legados, a infraestrutura cresce com alguns padrões que acabam se repetindo:

* ambientes semelhantes criados de formas diferentes;
* configurações feitas manualmente;
* dependência de pessoas específicas para operar;
* dificuldade de auditoria e governança;
* disaster recovery tratado como documentação, não como prática.

O brainctl é uma tentativa prática de resolver esses problemas aplicando:

* contratos declarativos simples;
* validações automáticas;
* geração estruturada de Terraform;
* observabilidade e recovery como parte do deploy, não como etapa posterior.

---

## Objetivo do projeto

O objetivo do brainctl não é ser um produto comercial pronto.
Ele é uma base de experimentação e aprendizado para construir uma abordagem de **Infraestrutura como Produto**.

Isso significa:

* Infra deixa de ser apenas provisionamento técnico;
* Passa a ser uma plataforma reutilizável para times;
* Com regras, padrões e previsibilidade.

---

## Ideia central

```text
app.yaml (+ overrides)
        ↓
validação e guardrails
        ↓
geração de Terraform estruturado
        ↓
provisionamento AWS
        ↓
ambiente já preparado para operação
```

O foco é permitir que times descrevam o workload necessário enquanto o brainctl garante padrões mínimos de segurança, disponibilidade e governança.

---

## Arquitetura do projeto

```text
cmd/brainctl                # entrada da CLI
internal/config             # parser, defaults e validações
internal/generator          # geração do workspace Terraform
internal/blueprints/ec2app  # blueprint de workload
internal/terraform          # wrapper de comandos Terraform
internal/workspace          # preparação do diretório de execução
terraform-modulesec2-app    # módulo Terraform base
stacks/dev|prod             # contratos por ambiente
```

---

## Workload suportado atualmente

### ec2-app

Blueprint focado em aplicações que ainda rodam em EC2, muito comum em ambientes corporativos.

Inclui:

* Instância de aplicação
* Instância de banco opcional
* Security Groups padronizados
* Outputs operacionais para troubleshooting e automação

---

## Escalabilidade e disponibilidade

O brainctl permite provisionar:

* Application Load Balancer público ou privado
* Target groups e listeners
* Auto Scaling Group para camada de aplicação
* Políticas baseadas em CPU
* Suporte a multi-AZ

### Guardrails aplicados

* Não permite Auto Scaling sem Load Balancer
* Impede configurações que gerariam ambiente inconsistente

---

## Observabilidade operacional

O projeto provisiona automaticamente:

* Dashboards CloudWatch
* Alarmes configuráveis
* Notificações via SNS
* Integração com Session Manager
* Configuração contínua do CloudWatch Agent via SSM State Manager (sem rebuild de instância)
* Suporte a endpoints privados de SSM, CloudWatch (Logs/Metrics) e STS
* Endpoints privados distribuídos nas subnets configuradas para infraestrutura

Objetivo: o ambiente nasce com visibilidade operacional mínima garantida.

---

## Recovery e continuidade

Implementado como parte do blueprint, não como solução separada:

* Snapshots automáticos via DLM
* Runbooks SSM para restore
* Restore completo de aplicação
* DR drill agendado via EventBridge

### Guardrails de recovery

Exemplos:

* DR drill exige recovery habilitado
* Backup de banco exige banco ativo
* DR com registro em load balancer valida pré-requisitos de observabilidade e disponibilidade

---

## Contrato declarativo

Exemplo simplificado:

```yaml
workload:
  type: ec2-app
  version: v1

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

A proposta é manter o contrato compreensível para times de aplicação, não apenas para especialistas em Terraform.

---

## Overrides controlados

O brainctl permite customizações, mas dentro de uma whitelist para evitar drift e mudanças perigosas.

Atualmente suportado:

* regras extras de Security Group
* ajustes específicos de acesso

---

## Execução da CLI

```bash
go run ./cmd/brainctl plan   --stack-dir stacks/dev
go run ./cmd/brainctl apply  --stack-dir stacks/dev
go run ./cmd/brainctl destroy --stack-dir stacks/dev
go run ./cmd/brainctl status --stack-dir stacks/dev
go run ./cmd/brainctl output --stack-dir stacks/dev
```

---

## User Data externo

Para manter contratos limpos:

```yaml
ec2:
  user_data_mode: merge
  user_data: file://scripts/app-user-data.ps1
```

---

## Outputs gerados

Exemplos:

* IPs e IDs das instâncias
* Nome do ASG
* DNS do Load Balancer
* URLs de dashboards
* Runbooks de recovery
* Agenda de DR drill

---

Esse projeto também serve como laboratório para testar ideias que podem ser aplicadas em ambientes corporativos reais.

---

## Limitações atuais

O projeto ainda é experimental e focado em:

* workloads EC2
* ambientes AWS
* blueprint específico

Ele não tenta ser uma plataforma universal nem substituir soluções completas de IDP.

---

## Próximos estudos e evoluções

Direções que pretendo explorar:

* novos blueprints
* melhoria de validações
* integração com pipelines CI/CD
* evolução da estratégia de DR
* integração com práticas de segurança mais profundas, com novas automações de resposta a incidentes.

---

## Conclusão

O brainctl é uma tentativa prática de tratar infraestrutura com o mesmo cuidado que tratamos aplicações: com versionamento, contratos claros e previsibilidade operacional.

Ele nasceu como projeto pessoal, mas reflete desafios comuns em ambientes corporativos e serve como base para explorar modelos mais maduros de operação em cloud.

---
