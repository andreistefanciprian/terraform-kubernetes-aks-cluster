# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Variables
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  # Remove this line to allow Terraform to register resource providers automatically
  # resource_provider_registrations = "none"
  features {}
}

# Resource Group for the storage account
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate-${random_string.suffix.result}"
  location = var.location

  tags = {
    Environment = "terraform-state"
    Purpose     = "terraform-backend"
  }
}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage Account for Terraform state
# Azure storage account names must be 3-24 characters. The prefix is kept short to allow for an 8-character random suffix.
  name                     = "sttfs${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Enable versioning for state file history
  blob_properties {
    versioning_enabled = true
  }

  tags = {
    Environment = "terraform-state"
    Purpose     = "terraform-backend"
  }
}

# Storage Container for Terraform state files
resource "azurerm_storage_container" "tfstate" {
  name                  = "terraform-state-${random_string.suffix.result}"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

# Outputs for backend configuration
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.tfstate.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.tfstate.name
}

# The storage account access key is not exposed as an output for security reasons.
# If you need to retrieve the key, use the Azure CLI:
# az storage account keys list --resource-group <resource_group> --account-name <storage_account>

output "container_name" {
  description = "Name of the main tfstate container"
  value       = azurerm_storage_container.tfstate.name
}

output "backend_config" {
  description = "Backend configuration for Terraform"
  value = {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    key                  = "terraform.tfstate"
  }
}
