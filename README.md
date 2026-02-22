# brainctl 🧠

> Original Portuguese version: [README.pt.md](README.pt.md)

Infrastructure as a contract, not improvisation

---

## About the project

**brainctl** is a project born from real-world experience working with growing corporate infrastructure.
It does not try to reinvent Terraform or replace existing tools. The idea is simpler: to study ways to help teams standardize infrastructure, reduce operational errors, and apply security and observability from the start, without requiring everyone to be specialists in Terraform and IaC management.

This project also represents my deepening studies in **Platform Engineering**, **Cloud Security**, and **product-oriented infrastructure automation**.

---

## Context and motivation

In many corporate environments, especially with legacy workloads, infrastructure grows with repeating patterns:

* similar environments created in different ways;
* manually made configurations;
* dependence on specific people to operate;
* audit and governance difficulty;
* disaster recovery treated as documentation, not as practice.

brainctl is a practical attempt to solve these problems by applying:

* simple declarative contracts;
* automatic validations;
* structured Terraform generation;
* observability and recovery as part of deployment, not as a later step.

---

## Project goal

The goal of brainctl is not to be a finished commercial product.
It is an experimentation and learning foundation to build an **Infrastructure as a Product** approach.

This means:

* Infrastructure stops being just technical provisioning;
* It becomes a reusable platform for teams;
* With rules, standards, and predictability.

---

## Core idea

```text
app.yaml (+ security-groups/*.yaml)
        ↓
validation and guardrails
        ↓
structured Terraform generation
        ↓
AWS provisioning
        ↓
environment already prepared for operation
```

The focus is to let teams describe the required workload while brainctl guarantees minimum standards of security, availability, and governance.

---

## Project architecture

```text
cmd/brainctl                # CLI entrypoint
internal/config             # parser, defaults, and validations
internal/generator          # Terraform workspace generation
internal/blueprints/ec2app  # EC2 app workload blueprint
internal/blueprints/k8sworkers # Kubernetes lab workload blueprint
internal/terraform          # Terraform command wrapper
internal/workspace          # execution directory preparation
terraform-modulesec2-app    # base Terraform module for ec2-app
terraform-modulesk8s-workers # Terraform module for k8s-workers blueprint
stacks/ec2-app/dev|prod     # ec2-app blueprint contracts
stacks/k8s-workers/dev|prod # k8s-workers blueprint contracts
```

---

## Workloads currently supported

### ec2-app

Blueprint focused on applications that still run on EC2, very common in corporate environments.

Includes:

* Application instance
* Optional database instance
* Standardized Security Groups
* Operational outputs for troubleshooting and automation

### k8s-workers

Didactic blueprint for self-managed Kubernetes on EC2 using kubeadm (without EKS).

Includes:

* 1 control-plane + N workers
* automatic bootstrap with kubeadm init/join
* minimum Security Group for API server and traffic between nodes
* kubeconfig and cluster validation instructions

Technical documentation:
- `docs/blueprints/ec2-app.md`
- `docs/blueprints/kubernetes-workers.md`
- `docs/cicd-v1.md`

---

## Scalability and availability

brainctl allows provisioning:

* Public or private Application Load Balancer
* Target groups and listeners
* Auto Scaling Group for the application layer
* CPU-based policies
* Multi-AZ support

### Applied guardrails

* Does not allow Auto Scaling without Load Balancer
* Prevents configurations that would generate an inconsistent environment

---

## Operational observability

The project automatically provisions:

* CloudWatch dashboards
* Configurable alarms
* SNS notifications
* Session Manager integration
* Continuous CloudWatch Agent configuration through SSM State Manager (without instance rebuild)
* Support for private endpoints of SSM, CloudWatch (Logs/Metrics), and STS
* Private endpoints distributed across configured subnets for infrastructure

Goal: the environment is created with a guaranteed minimum operational visibility.

---

## Recovery and continuity

Implemented as part of the blueprint, not as a separate solution:

* Automatic snapshots through DLM
* SSM runbooks for restore
* Full application restore
* Scheduled DR drill through EventBridge

### Recovery guardrails

Examples:

* DR drill requires recovery enabled
* Database backup requires active database
* DR with load balancer registration validates observability and availability prerequisites

---

## Declarative contract

Simplified example:

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

observability:
  enabled: true

recovery:
  enabled: true
```

The proposal is to keep the contract understandable for application teams, not only for Terraform specialists.

> Terraform remote backend is configured through the contract (`terraform.backend`) to avoid hardcoding bucket/region and allow isolation by company/account/environment.

---

## Security Group rules by files

brainctl allows network customizations through YAML files per SG in `security-groups/`, keeping scope controlled by type (`app`, `db`, `alb`).

---

## How to run

### Prerequisites

* Go 1.22+
* Terraform installed and in PATH
* AWS credentials with provisioning permissions

### Main commands

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

### Example for k8s-workers

```bash
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl apply --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl destroy --stack-dir stacks/k8s-workers/dev
```

---

## Terraform backend (remote state)

Configure in contract through `terraform.backend`:

- `bucket`: S3 bucket for remote state.
- `key_prefix`: prefix to isolate state by team/company (final key includes app and environment).
- `region`: region of the state bucket.
- `use_lockfile`: enables state locking in S3 backend.

## Main guardrails

- Auto Scaling without Load Balancer is blocked during validation.
- Recovery operations validate prerequisites of dependent resources.
- Extra Security Group rules are read from files in `security-groups/` by SG type (`app`, `db`, `alb`).

## Expected outputs

Depending on resource combination, outputs include:

- IDs and IPs of instances.
- ALB DNS.
- ASG name.
- observability references (dashboards/alarms).
- artifacts and commands related to recovery.

## CLI operation

```bash
go run ./cmd/brainctl plan --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl apply --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl status --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl output --stack-dir stacks/ec2-app/dev
go run ./cmd/brainctl destroy --stack-dir stacks/ec2-app/dev
```

## Reference directories

- base contract: `stacks/ec2-app/dev/app.yaml`
- production contract: `stacks/ec2-app/prod/app.yaml`
- SG rules: `stacks/ec2-app/*/security-groups/*.yaml`
- example bootstrap script: `stacks/ec2-app/*/scripts/app-user-data.ps1`
