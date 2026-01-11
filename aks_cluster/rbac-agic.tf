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
