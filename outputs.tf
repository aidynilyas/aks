# outputs.tf

output "resource_group_name" {
  description = "The name of the Azure Resource Group."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "get_credentials_command" {
  description = "Command to get AKS credentials and configure kubectl."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-kubeconfig"
}

output "dashboard_service_account_name" {
  description = "The name of the ServiceAccount for the Kubernetes Dashboard admin user."
  value       = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
}

output "dashboard_namespace" {
  description = "The namespace where the Kubernetes Dashboard is deployed."
  value       = helm_release.kubernetes_dashboard.namespace
}

output "kubectl_proxy_command" {
  description = "Command to start kubectl proxy to access the Kubernetes Dashboard."
  value       = "kubectl proxy"
}
