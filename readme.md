# brainctl 🧠

brainctl is a CLI tool that automates AWS infrastructure provisioning using Terraform based on a simple declarative YAML configuration.

The project aims to simplify infrastructure creation and standardize cloud environments through automation and reusable Terraform modules.

---

## 🚀 What brainctl does

Given a configuration file (`app.yaml`), brainctl:

* Validates infrastructure configuration
* Generates Terraform workspaces automatically
* Injects internal Terraform modules
* Manages remote Terraform state (S3 + DynamoDB)
* Runs Terraform plan to preview infrastructure changes

---

## 📄 Example Configuration

```yaml
app:
  name: brain-test
  environment: dev
  region: sa-east-1

infrastructure:
  vpc_id: vpc-xxxx
  subnet_id: subnet-xxxx

ec2:
  instance_type: t3.micro
  os: windows2022
```

---

## ▶️ Usage

Run:

```bash
go run ./cmd/brainctl plan
```

brainctl will:

1. Parse and validate the YAML file
2. Generate Terraform workspace
3. Initialize Terraform backend
4. Run Terraform plan

---

## ⚙️ Requirements

* Go 1.22+
* Terraform 1.6+
* AWS credentials configured locally

---

## 🗺 Roadmap

* Apply / Destroy lifecycle commands
* Drift detection
* Multi-tier architecture support
* Monitoring automation
* Governance and policy controls

---

## 📜 License

MIT
