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

# Verify
az account show --output table

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
az ad sp create-for-rbac --name "terraform" --role="Owner" --scopes="/subscriptions/<SUBSCRIPTION_ID>"

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

## Application Gateway with HTTPS/TLS

The AKS cluster includes an Application Gateway Ingress Controller (AGIC) with support for HTTPS/TLS termination.

### HTTPS Configuration

By default, the Application Gateway is configured with HTTP support. To enable HTTPS/TLS:

1. **Upload SSL certificate to Key Vault**:
   ```bash
   # Get the Key Vault name (it will be aks-certs-<random-suffix>)
   az keyvault list --resource-group <your-rg-name> --output table
   
   # Import your certificate (PFX format with private key)
   az keyvault certificate import \
     --vault-name <key-vault-name> \
     --name my-app-cert \
     --file /path/to/certificate.pfx \
     --password <pfx-password>
   ```

2. **Configure Terraform variables**:
   Update your `aks_cluster/terraform.tfvars` or pass variables:
   ```hcl
   appgw_ssl_certificate_name = "my-app-cert"  # Name of certificate in Key Vault
   appgw_enable_http_redirect = true            # Auto-redirect HTTP to HTTPS
   ```

3. **Apply the changes**:
   ```bash
   make deploy-auto-approve TF_TARGET=aks_cluster
   ```

### Security Features

- **TLS Termination**: Application Gateway terminates TLS/SSL at the gateway
- **HTTP to HTTPS Redirect**: Automatic permanent redirect from HTTP (port 80) to HTTPS (port 443)
- **Key Vault Integration**: Certificates are securely stored in Azure Key Vault
- **Managed Identity**: Application Gateway uses managed identity to access certificates

**Note**: Without a certificate configured, the Application Gateway operates in HTTP-only mode on port 80. For production environments, always configure HTTPS with a valid SSL certificate.

## Cleanup
```bash
# Destroy AKS cluster first
make destroy-auto-approve TF_TARGET=aks_cluster

# Then destroy state storage
docker compose run --rm terraform -chdir=tf_bucket destroy -auto-approve
```