# Application Gateway Ingress Controller (AGIC) Infrastructure
# This file contains all resources related to Application Gateway, Key Vault for certificates,
# and their associated networking components.

# Managed Identity for Application Gateway (for Key Vault access)
resource "azurerm_user_assigned_identity" "appgw_identity" {
  count = var.enable_application_gateway ? 1 : 0

  name                = "appgw-identity"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  tags = var.tags
}

# Key Vault for SSL certificates
resource "azurerm_key_vault" "certs" {
  count = var.enable_application_gateway ? 1 : 0

  name                       = "aks-certs-${random_string.suffix.result}"
  location                   = azurerm_resource_group.aks.location
  resource_group_name        = azurerm_resource_group.aks.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Network access - restrict to Application Gateway subnet and Azure services
  # For production: change default_action to "Deny" and add ip_rules for management access
  network_acls {
    default_action             = "Allow" # Change to "Deny" for production
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [] # Add [azurerm_subnet.appgw_subnet[0].id] when default_action = "Deny"
    ip_rules                   = [] # Add trusted IP ranges (e.g., ["1.2.3.4/32"]) when default_action = "Deny"
  }

  tags = var.tags
}

# Grant Application Gateway managed identity access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "appgw_certs" {
  count = var.enable_application_gateway ? 1 : 0

  key_vault_id = azurerm_key_vault.certs[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]
}

# Grant current user/service principal access to manage certificates
resource "azurerm_key_vault_access_policy" "current_user" {
  count = var.enable_application_gateway ? 1 : 0

  key_vault_id = azurerm_key_vault.certs[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Import",
    "Delete",
    "Purge",
    "Recover",
    "Update",
    "ManageContacts",
    "ManageIssuers",
    "GetIssuers",
    "ListIssuers",
    "SetIssuers",
    "DeleteIssuers"
  ]
}

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  count = var.enable_application_gateway ? 1 : 0

  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  count = var.enable_application_gateway ? 1 : 0

  name                = "appgw-pip"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Local values for Application Gateway configuration
locals {
  # Determine if HTTPS is enabled
  appgw_https_enabled = var.enable_application_gateway && var.appgw_ssl_certificate_name != ""

  # Determine if HTTP to HTTPS redirect is enabled
  appgw_redirect_enabled = local.appgw_https_enabled && var.appgw_enable_http_redirect

  # Determine if HTTP routing should be enabled (when HTTPS is not configured or redirect is disabled)
  appgw_http_routing_enabled = !local.appgw_redirect_enabled
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  count = var.enable_application_gateway ? 1 : 0

  name                = "aks-appgw"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  sku {
    name = var.appgw_sku
    tier = var.appgw_sku
  }

  autoscale_configuration {
    min_capacity = var.appgw_min_capacity
    max_capacity = var.appgw_max_capacity
  }

  # Enable managed identity for Key Vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity[0].id]
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet[0].id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip[0].id
  }

  frontend_ip_configuration {
    name                          = "appgw-frontend-private-ip"
    subnet_id                     = azurerm_subnet.appgw_subnet[0].id
    private_ip_address            = var.appgw_private_ip
    private_ip_address_allocation = "Static"
  }

  backend_address_pool {
    name = "default-backend-pool"
  }

  probe {
    name                                      = "default-health-probe"
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 15
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "default-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = "default-health-probe"
    pick_host_name_from_backend_address = true
  }

  # SSL certificate from Key Vault (only when certificate name is provided)
  dynamic "ssl_certificate" {
    for_each = local.appgw_https_enabled ? [1] : []
    content {
      name                = "appgw-ssl-cert"
      key_vault_secret_id = var.certificate_version != "" ? "${azurerm_key_vault.certs[0].vault_uri}secrets/${var.appgw_ssl_certificate_name}/${var.certificate_version}" : "${azurerm_key_vault.certs[0].vault_uri}secrets/${var.appgw_ssl_certificate_name}"
    }
  }

  # HTTP listener on port 80
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # HTTPS listener on port 443 (only when certificate is available)
  dynamic "http_listener" {
    for_each = local.appgw_https_enabled ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "appgw-frontend-ip"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "appgw-ssl-cert"
    }
  }

  # Redirect configuration for HTTP to HTTPS (only when HTTPS is enabled)
  dynamic "redirect_configuration" {
    for_each = local.appgw_redirect_enabled ? [1] : []
    content {
      name                 = "http-to-https-redirect"
      redirect_type        = "Permanent"
      target_listener_name = "https-listener"
      include_path         = true
      include_query_string = true
    }
  }

  # HTTP to HTTPS redirect rule (only when HTTPS is enabled and redirect is enabled)
  dynamic "request_routing_rule" {
    for_each = local.appgw_redirect_enabled ? [1] : []
    content {
      name                        = "http-redirect-rule"
      rule_type                   = "Basic"
      http_listener_name          = "http-listener"
      redirect_configuration_name = "http-to-https-redirect"
      priority                    = 100
    }
  }

  # HTTPS routing rule to backend (only when HTTPS is enabled)
  dynamic "request_routing_rule" {
    for_each = local.appgw_https_enabled ? [1] : []
    content {
      name                       = "https-routing-rule"
      rule_type                  = "Basic"
      http_listener_name         = "https-listener"
      backend_address_pool_name  = "default-backend-pool"
      backend_http_settings_name = "default-http-settings"
      priority                   = 200
    }
  }

  # Fallback HTTP routing rule (when HTTPS is not configured or redirect is disabled)
  dynamic "request_routing_rule" {
    for_each = local.appgw_http_routing_enabled ? [1] : []
    content {
      name                       = "http-routing-rule"
      rule_type                  = "Basic"
      http_listener_name         = "http-listener"
      backend_address_pool_name  = "default-backend-pool"
      backend_http_settings_name = "default-http-settings"
      priority                   = 300
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.appgw_certs
  ]
}

# RBAC role assignments for Application Gateway Ingress Controller (AGIC)

# Role assignment for AGIC - Contributor on Application Gateway
resource "azurerm_role_assignment" "agic_appgw" {
  count = var.enable_application_gateway ? 1 : 0

  scope                = azurerm_application_gateway.appgw[0].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_application_gateway.appgw
  ]
}

# Role assignment for AGIC - Reader on Resource Group
resource "azurerm_role_assignment" "agic_rg" {
  count = var.enable_application_gateway ? 1 : 0

  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_resource_group.aks
  ]
}

# AGIC also needs permission to use the App Gateway subnet during AppGW updates.
resource "azurerm_role_assignment" "agic_appgw_subnet" {
  count = var.enable_application_gateway ? 1 : 0

  scope                = azurerm_subnet.appgw_subnet[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_subnet.appgw_subnet
  ]
}

# App Gateway has a user-assigned identity (used for Key Vault access). When AGIC updates the
# Application Gateway, ARM validates that the caller can assign that identity.
resource "azurerm_role_assignment" "agic_appgw_identity_operator" {
  count = var.enable_application_gateway ? 1 : 0

  scope                = azurerm_user_assigned_identity.appgw_identity[0].id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_user_assigned_identity.appgw_identity
  ]
}