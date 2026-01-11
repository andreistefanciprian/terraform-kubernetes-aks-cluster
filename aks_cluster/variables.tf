# define Azure region
variable "azure_region" {
  type        = string
  description = "Azure region"
  default     = "Australia East"
}

# define resource group name prefix
variable "resource_group_prefix" {
  type        = string
  description = "Resource group name prefix"
  default     = "rg-aks"
}

variable "maintenance_window" {
  description = "Time window specified for daily maintenance operations to START in UTC format (HH:MM)"
  type        = string
  default     = "05:00"
}

variable "node_type" {
  type        = string
  description = "VM size for AKS nodes"
  default     = "Standard_D2s_v3"
}

variable "node_disk_type" {
  type        = string
  description = "Disk type for AKS nodes"
  default     = "Managed"
}

variable "node_disk_size" {
  type        = number
  description = "Disk size in GB for AKS nodes"
  default     = 30
}

variable "service_account_name_cluster" {
  type        = string
  description = "Name for the cluster managed identity"
  default     = "aks-cluster-identity"
}

variable "aks_num_nodes" {
  default     = 1
  description = "Number of AKS nodes"
  type        = number
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for AKS cluster"
  default     = "1.33.3" # Updated to latest GA version without LTS requirement
}

variable "vnet_cidr" {
  type        = string
  description = "CIDR block for the VNet"
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the AKS subnet"
  default     = "10.10.1.0/24"
}

variable "appgw_subnet_cidr" {
  type        = string
  description = "CIDR block for the Application Gateway subnet"
  default     = "10.10.2.0/24"
}

variable "appgw_sku" {
  type        = string
  description = "SKU for Application Gateway"
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  type        = number
  description = "Capacity (instance count) for Application Gateway"
  default     = 2
}

variable "appgw_private_ip" {
  type        = string
  description = "Private IP address for Application Gateway frontend"
  default     = "10.10.2.10"

  validation {
    condition = can(
      regex(
        "^${join("\\.", slice(split(".", cidrhost(var.appgw_subnet_cidr, 0)), 0, 3))}\\.(?:[1-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4])$",
        var.appgw_private_ip
      )
    )
    error_message = "appgw_private_ip must be a valid IPv4 address within the appgw_subnet_cidr range and not the network or broadcast address."
  }
}

variable "enable_key_vault" {
  type        = bool
  description = "Enable Key Vault for certificate management"
  default     = true
}

variable "key_vault_sku" {
  type        = string
  description = "SKU for Key Vault"
  default     = "standard"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AKS-Cluster"
    Owner       = "DevOps-Team"
  }
}