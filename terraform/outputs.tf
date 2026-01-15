output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.idp.name
}

output "cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.idp.id
}

output "kube_config" {
  description = "Kubernetes configuration for kubectl"
  value       = azurerm_kubernetes_cluster.idp.kube_config_raw
  sensitive   = true
}

output "acr_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.idp.login_server
}

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.idp.name
}
