# Private AKS Cluster with Terraform

Terraform code to deploy a private Azure Kubernetes Service (AKS) cluster.

## Prerequisites
- Azure CLI
- Docker & Docker Compose
- Valid Azure subscription with appropriate permissions

## Quick Start

1. **Login and setup Azure**:
```bash
az login
```

2. **Configure authentication** - Update `.env` with your Azure service principal credentials:
```bash
cp .env.example .env
# Edit .env with your ARM_* values
```

3. **Create storage for Terraform state**:
```bash
docker compose run --rm terraform -chdir=tf_bucket init
docker compose run --rm terraform -chdir=tf_bucket apply -auto-approve
```

4. **Deploy AKS cluster**:
```bash
make show-backend-config    # Check Azure backend config is configured correctly
make plan TF_TARGET=aks_cluster
make deploy-auto-approve TF_TARGET=aks_cluster
```

## Cleanup
```bash
# Destroy AKS cluster first
make destroy-auto-approve TF_TARGET=aks_cluster

# Then destroy state storage
docker compose run --rm terraform -chdir=tf_bucket destroy -auto-approve
```