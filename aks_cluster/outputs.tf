# AKS Cluster outputs
output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.aks.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kubelet_identity" {
  description = "Kubelet identity object ID for role assignments"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}