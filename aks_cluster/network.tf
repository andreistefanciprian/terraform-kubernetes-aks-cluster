# Resource Group for the AKS cluster
resource "azurerm_resource_group" "aks" {
  name     = "${var.resource_group_prefix}-${random_string.suffix.result}"
  location = var.azure_region

  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "aks-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = var.tags
}

# Subnet for AKS nodes
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# Route table for network policies
resource "azurerm_route_table" "aks_route_table" {
  name                = "aks-route-table"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  # Empty route table - used for network policies and future routing rules
  # With loadBalancer outbound type, Azure manages the outbound connectivity

  tags = var.tags
}

# Associate route table with subnet
resource "azurerm_subnet_route_table_association" "aks_route_association" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  route_table_id = azurerm_route_table.aks_route_table.id
}

# Network Security Group for AKS subnet
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "aks-nsg"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  # Allow SSH for debugging (not recommended in production)
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "aks_nsg_association" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "aks-appgw"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  sku {
    name     = var.appgw_sku
    tier     = var.appgw_sku
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
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
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_ip_configuration {
    name                          = "appgw-frontend-private-ip"
    subnet_id                     = azurerm_subnet.appgw_subnet.id
    private_ip_address            = var.appgw_private_ip
    private_ip_address_allocation = "Static"
  }

  backend_address_pool {
    name = "default-backend-pool"
  }

  backend_http_settings {
    name                  = "default-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "default-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "default-backend-pool"
    backend_http_settings_name = "default-http-settings"
    priority                   = 100
  }

  tags = var.tags
}