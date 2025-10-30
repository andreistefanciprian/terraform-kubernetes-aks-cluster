# AKS Cluster with Terraform

Terraform code to deploy an Azure Kubernetes Service (AKS) cluster with public API endpoint and private nodes (similar to [GKE setup](https://github.com/andreistefanciprian/terraform-kubernetes-gke-cluster)).

## Prerequisites
- Azure CLI
- Docker & Docker Compose
- Valid Azure subscription with appropriate permissions

## Quick Start

1. **Login and setup Azure**:
```bash
az login

# Register required Azure resource providers
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Authorization
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ManagedIdentity

# Check registration status (optional)
az provider show --namespace Microsoft.ContainerService --query "registrationState"
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
# Plan and deploy the AKS cluster (public API, private nodes)
make plan TF_TARGET=aks_cluster
make deploy-auto-approve TF_TARGET=aks_cluster

# Configure kubectl to access the cluster
# List all AKS clusters to find your resource group name
az aks list --output table

# Get credentials for your cluster (replace with actual resource group name from above)
az aks get-credentials --resource-group <your-rg-name> --name aks-cluster --admin

# Verify cluster access
kubectl cluster-info
```

## Cleanup
```bash
# Destroy AKS cluster first
make destroy-auto-approve TF_TARGET=aks_cluster

# Then destroy state storage
docker compose run --rm terraform -chdir=tf_bucket destroy -auto-approve
```