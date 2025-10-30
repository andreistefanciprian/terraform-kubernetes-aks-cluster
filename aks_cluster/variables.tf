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

variable "aks_master_cidr" {
  type        = string
  description = "Private IP subnet for AKS control plane (when using private endpoint)"
  default     = "172.16.0.0/28"
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