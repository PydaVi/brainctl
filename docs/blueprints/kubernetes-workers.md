# Blueprint `k8s-workers`

## 1. Escopo

O blueprint `k8s-workers` provisiona um cluster Kubernetes self-managed em EC2, baseado em `kubeadm`, com foco em ambientes de laboratório e validação técnica.

A implementação atual cobre:

- 1 nó `control-plane`.
- N nós `worker`.
- bootstrap automatizado via `user_data`.
- integração opcional com AWS Systems Manager (SSM).
- caminho opcional de saída para internet via NAT Gateway para instalação de dependências de bootstrap.

## 2. Topologia provisionada

### 2.1 Recursos principais

- `aws_instance.control_plane`
- `aws_instance.workers`
- `aws_security_group.cluster`
- `aws_iam_role.instance`
- `aws_iam_instance_profile.instance`

### 2.2 Recursos opcionais (SSM)

Quando `k8s.enable_ssm: true` e `k8s.enable_ssm_vpc_endpoints: true`:

- `aws_security_group.ssm_endpoints`
- `aws_vpc_endpoint.ssm`
- `aws_vpc_endpoint.ssmmessages`
- `aws_vpc_endpoint.ec2messages`

### 2.3 Recursos opcionais (egresso via NAT)

Quando `k8s.enable_nat_gateway: true`:

- `aws_eip.nat`
- `aws_nat_gateway.cluster`
- `aws_route.private_internet_via_nat`
- `aws_subnet.nat_public` (quando `public_subnet_id` não for informado)
- `aws_route_table.nat_public` + associação
- `aws_route_table.private_nat` + associação (quando `private_route_table_id` não for informado)

## 3. Fluxo de bootstrap

1. Instância de control-plane inicializa e instala runtime/container tooling e binários Kubernetes.
2. `kubeadm init` executa no control-plane.
3. Token/comando de join é disponibilizado internamente para os workers.
4. Workers executam `kubeadm join` automaticamente.
5. Com CNI aplicado pelo bootstrap, os nós convergem para estado `Ready`.

## 4. Requisitos de rede

### 4.1 Tráfego interno do cluster

- Permissão de tráfego entre nós no mesmo security group (`self`).
- Porta `6443/tcp` entre nós para API server.

### 4.2 Acesso administrativo

- Porta `22/tcp` opcional, controlada por `k8s.admin_cidr`.
- Alternativamente, acesso via SSM quando habilitado.

### 4.3 Dependências de internet para bootstrap

A instalação de dependências (apt, repositórios Kubernetes, pull de imagens) requer conectividade de saída.

Opções suportadas:

- subnet com rota de internet já existente; ou
- NAT Gateway gerenciado pelo blueprint (`enable_nat_gateway: true`).

## 5. Contrato de configuração (`app.yaml`)

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
  key_name: ""
  admin_cidr: "0.0.0.0/0"

  # caminho de egresso opcional via NAT
  enable_nat_gateway: true
  public_subnet_id: ""
  public_subnet_cidr: "10.0.254.0/24"
  internet_gateway_id: ""
  private_route_table_id: ""

  # operação e acesso
  enable_ssm: true
  enable_ssm_vpc_endpoints: true
  enable_detailed_monitoring: false
```

## 6. Semântica dos parâmetros de NAT

- `enable_nat_gateway`
  - `true`: habilita criação/configuração de caminho NAT para egress.
  - `false`: não provisiona recursos de NAT.

- `public_subnet_id`
  - informado: reutiliza subnet pública existente para o NAT Gateway.
  - vazio: cria subnet pública no mesmo AZ do `subnet_id` privado.

- `public_subnet_cidr`
  - usado apenas quando `public_subnet_id` está vazio.

- `internet_gateway_id`
  - informado: reutiliza IGW existente.
  - vazio: faz descoberta de IGW anexado à VPC.

- `private_route_table_id`
  - informado: cria rota default para NAT na route table especificada.
  - vazio: cria route table privada dedicada e associa ao `subnet_id`.

## 7. Outputs esperados

O blueprint publica, entre outros:

- ID/IP/DNS do control-plane.
- IDs das instâncias worker.
- instruções para recuperação de kubeconfig.
- comando de validação do cluster.

## 8. Operação via CLI

```bash
go run ./cmd/brainctl plan --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl apply --stack-dir stacks/k8s-workers/dev
go run ./cmd/brainctl destroy --stack-dir stacks/k8s-workers/dev
```

## 9. Limitações conhecidas

- arquitetura sem alta disponibilidade de control-plane.
- sem integração EKS (control plane gerenciado).
- fluxo de join simplificado para laboratório.
- sem rotina de upgrade automatizado de versão Kubernetes.
