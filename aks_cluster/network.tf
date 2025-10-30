# Resource Group for the AKS cluster
resource "azurerm_resource_group" "aks" {
  name     = "${var.resource_group_prefix}-${random_string.suffix.result}"
  location = var.azure_region

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "aks-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }
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

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }
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

  tags = {
    Environment = "aks-cluster"
    Purpose     = "kubernetes"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "aks_nsg_association" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# NAT Gateway for outbound internet connectivity
resource "azurerm_public_ip" "nat_gateway_ip" {
  name                = "nat-gateway-ip"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "aks-cluster"
    Purpose     = "nat-gateway"
  }
}

resource "azurerm_nat_gateway" "aks_nat" {
  name                    = "aks-nat-gateway"
  location                = azurerm_resource_group.aks.location
  resource_group_name     = azurerm_resource_group.aks.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4

  tags = {
    Environment = "aks-cluster"
    Purpose     = "nat-gateway"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "aks_nat_ip" {
  nat_gateway_id       = azurerm_nat_gateway.aks_nat.id
  public_ip_address_id = azurerm_public_ip.nat_gateway_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "aks_subnet_nat" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  nat_gateway_id = azurerm_nat_gateway.aks_nat.id
}