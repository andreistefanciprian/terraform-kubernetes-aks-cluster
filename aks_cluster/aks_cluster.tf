# User Assigned Managed Identity for AKS cluster
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = var.service_account_name_cluster
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }
}

# Note: Role assignment removed due to insufficient permissions
# The AKS service will automatically create necessary role assignments

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-cluster"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "aks-cluster"
  kubernetes_version  = var.kubernetes_version

  # Public cluster configuration (similar to GKE setup)
  # API server is public, nodes are private
  private_cluster_enabled = false
  # private_dns_zone_id not needed for public clusters
  # private_cluster_public_fqdn_enabled not needed for public clusters

  # Network configuration with custom VNet and NAT Gateway
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/24"
    load_balancer_sku = "standard"
    # Use loadBalancer with our custom NAT Gateway for outbound connectivity
    outbound_type = "loadBalancer"
  }

  # Default node pool configuration
  default_node_pool {
    name                         = "default"
    vm_size                      = var.node_type
    os_disk_size_gb              = var.node_disk_size
    os_disk_type                 = var.node_disk_type
    vnet_subnet_id               = azurerm_subnet.aks_subnet.id
    only_critical_addons_enabled = false

    # Enable auto-scaling
    auto_scaling_enabled = true
    min_count            = var.aks_num_nodes # Use variable for minimum nodes
    max_count            = 3

    upgrade_settings {
      max_surge = "10%"
    }

    node_labels = {
      "environment" = "aks-cluster"
      "nodepool"    = "default"
    }
  }

  # Identity configuration
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  # Enable workload identity
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Maintenance window
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = var.maintenance_window
    utc_offset  = "+10:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = var.maintenance_window
    utc_offset  = "+10:00"
  }

  # Azure Monitor and logging
  monitor_metrics {}

  # Add-ons
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Azure Policy add-on
  azure_policy_enabled = true

  # HTTP application routing (not recommended for production)
  http_application_routing_enabled = false

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }

  depends_on = [
    azurerm_subnet_nat_gateway_association.aks_subnet_nat,
    azurerm_subnet_route_table_association.aks_route_association,
    azurerm_subnet_network_security_group_association.aks_nsg_association
  ]
}