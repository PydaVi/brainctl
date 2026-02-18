# Blueprint `k8s-workers` (Kubernetes self-managed em EC2)

> **Objetivo:** laboratório barato, didático e destrutível para aprender kubeadm sem EKS.

## Arquitetura (MVP)

- 1x EC2 `control-plane` com `kubeadm init`
- 2x EC2 `workers` com `kubeadm join` automático
- 1 Security Group compartilhado para cluster
- 1 IAM Role + Instance Profile para as instâncias
- Bootstrap via `user_data` (instala containerd + kubeadm/kubelet/kubectl)

Fluxo de rede mínimo:
- Porta `6443/tcp` (API Server) entre nós do cluster
- Tráfego node-to-node liberado dentro do próprio SG
- `22/tcp` opcional via `k8s.admin_cidr`
- Egress aberto para instalação de pacotes e pull de imagens

## Fluxo de bootstrap

1. Control-plane sobe primeiro.
2. User-data instala runtime e binários do Kubernetes.
3. `kubeadm init` cria o cluster.
4. Script gera `join.sh` e publica temporariamente em HTTP interno (`:8080`) no control-plane.
5. Workers sobem, baixam `join.sh` e executam `kubeadm join` automaticamente.
6. Com Flannel aplicado, os nós ficam `Ready`.

## Exemplo de contrato (`app.yaml`)

```yaml
workload:
  type: k8s-workers
  version: v1

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
  key_name: "minha-chave-ec2"
  admin_cidr: "0.0.0.0/0" # para lab; restrinja em ambientes reais
  enable_ssm: true
  enable_detailed_monitoring: false
```

## Contratos exemplo no repositório

- `stacks/k8s-workers/dev`
- `stacks/k8s-workers/prod`

Use esses contratos como ponto de partida e ajuste VPC/subnet/chave conforme sua conta.

## Outputs e validação

O blueprint publica outputs com:
- IP/DNS do control-plane
- IDs dos workers
- Instruções para obter kubeconfig
- Comando de validação

Validação recomendada:

```bash
ssh -i <key.pem> ubuntu@<control-plane-public-dns> 'kubectl get nodes -o wide'
```

Ou copie o kubeconfig e rode localmente:

```bash
scp -i <key.pem> ubuntu@<control-plane-public-dns>:/home/ubuntu/.kube/config ./kubeconfig
KUBECONFIG=./kubeconfig kubectl get nodes
```

## Como destruir

```bash
go run ./cmd/brainctl destroy --stack-dir stacks/k8s-workers/dev
```

Esse blueprint é intencionalmente efêmero: destrua e reprovisione sempre que quiser repetir o aprendizado.

## Custo e boas práticas

- Comece com `t3.medium` para control-plane e workers.
- Use apenas uma subnet para reduzir complexidade e custo no lab.
- Limite `admin_cidr` ao seu IP para reduzir exposição.
- Prefira `enable_ssm: true` para acesso sem SSH público.
- Desligue/destroi ao final do estudo.

## Limitações conhecidas

- **Sem HA** de control-plane.
- **Sem EKS** (sem managed control plane).
- **Sem hardening completo** de produção (cripto, auditoria, policies avançadas).
- Join via HTTP interno é simplificação didática para laboratório.
- Não faz upgrade automatizado de versão Kubernetes.

## Opinião prática (próximos passos)

Se quiser evoluir este blueprint sem perder simplicidade:

1. Mudar bootstrap para `cloud-init` em múltiplas fases (mais observabilidade de falha).
2. Trocar mecanismo de join para SSM Parameter Store (mais seguro que HTTP interno).
3. Separar SG de control-plane e workers.
4. Criar opção de multi-subnet para workers.
5. Adicionar instalação opcional de metrics-server e ingress-nginx.

