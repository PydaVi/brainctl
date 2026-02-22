# Blueprint `k8s-workers`

## English

### 1. Scope

`k8s-workers` provisions a self-managed Kubernetes cluster on EC2 using kubeadm, focused on labs and technical validation.

### 2. Current implementation

- 1 control-plane node
- N worker nodes
- Automated bootstrap through `user_data`
- Optional Systems Manager integration
- Optional NAT egress path for dependency installation

### 3. Main resources

- `aws_instance.control_plane`
- `aws_instance.workers`
- `aws_security_group.cluster`
- `aws_iam_role.instance`
- `aws_iam_instance_profile.instance`

Optional SSM endpoints:
- `aws_vpc_endpoint.ssm`
- `aws_vpc_endpoint.ssmmessages`
- `aws_vpc_endpoint.ec2messages`

Optional NAT resources:
- `aws_nat_gateway.cluster`
- `aws_route.private_internet_via_nat`
- related subnet/route table resources

### 4. Contract (`app.yaml`) example

```yaml
workload:
  type: k8s-workers
  version: v1

terraform:
  backend:
    bucket: "your-state-bucket"
    key_prefix: "brainctl"
    region: "us-east-1"
    use_lockfile: true

app:
  name: brain-k8s-lab
  environment: dev
  region: us-east-1

infrastructure:
  vpc_id: vpc-xxxxxxxx
  subnet_id: subnet-xxxxxxxx

k8s:
  control_plane_instance_type: t3.medium
  worker_instance_type: t3.medium
  worker_count: 2
  kubernetes_version: "1.30"
  pod_cidr: "10.244.0.0/16"
  admin_cidr: "0.0.0.0/0"
  enable_nat_gateway: true
  enable_ssm: true
  enable_ssm_vpc_endpoints: true
```

### 5. CLI operations

```bash
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl apply --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl destroy --stack-dir stacks/k8s-workers/dev
```

### 6. Known limitations

- No control-plane HA
- No EKS integration
- Simplified join flow for labs
- No automated Kubernetes version upgrades

---

## Português

### 1. Escopo

`k8s-workers` provisiona um cluster Kubernetes self-managed em EC2 com kubeadm, focado em laboratório e validação técnica.

### 2. Implementação atual

- 1 nó de control-plane
- N nós worker
- Bootstrap automatizado via `user_data`
- Integração opcional com Systems Manager
- Caminho opcional de saída via NAT para instalação de dependências

### 3. Recursos principais

- `aws_instance.control_plane`
- `aws_instance.workers`
- `aws_security_group.cluster`
- `aws_iam_role.instance`
- `aws_iam_instance_profile.instance`

Endpoints SSM opcionais:
- `aws_vpc_endpoint.ssm`
- `aws_vpc_endpoint.ssmmessages`
- `aws_vpc_endpoint.ec2messages`

Recursos NAT opcionais:
- `aws_nat_gateway.cluster`
- `aws_route.private_internet_via_nat`
- recursos relacionados de subnet/route table

### 4. Exemplo de contrato (`app.yaml`)

```yaml
workload:
  type: k8s-workers
  version: v1

terraform:
  backend:
    bucket: "seu-bucket-de-state"
    key_prefix: "brainctl"
    region: "us-east-1"
    use_lockfile: true

app:
  name: brain-k8s-lab
  environment: dev
  region: us-east-1

infrastructure:
  vpc_id: vpc-xxxxxxxx
  subnet_id: subnet-xxxxxxxx

k8s:
  control_plane_instance_type: t3.medium
  worker_instance_type: t3.medium
  worker_count: 2
  kubernetes_version: "1.30"
  pod_cidr: "10.244.0.0/16"
  admin_cidr: "0.0.0.0/0"
  enable_nat_gateway: true
  enable_ssm: true
  enable_ssm_vpc_endpoints: true
```

### 5. Operações via CLI

```bash
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl apply --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl destroy --stack-dir stacks/k8s-workers/dev
```

### 6. Limitações conhecidas

- Sem HA de control-plane
- Sem integração com EKS
- Fluxo de join simplificado para laboratório
- Sem rotina automática de upgrade de versão Kubernetes
