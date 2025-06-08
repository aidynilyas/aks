# variables.tf

variable "location" {
  description = "The Azure region where the resources will be deployed."
  type        = string
  default     = "East US" # Choose an Azure region, e.g., "East US", "West Europe"
}

variable "resource_group_name" {
  description = "The name of the Azure Resource Group to create/use for the AKS cluster."
  type        = string
  default     = "rg-my-aks-dashboard-cluster"
}

variable "aks_cluster_name" {
  description = "The name of the AKS cluster."
  type        = string
  default     = "my-aks-dashboard-cluster"
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.29" # Use a supported AKS version (e.g., "1.29.x")
}

variable "vm_size" {
  description = "The size of the Virtual Machine for the AKS worker nodes."
  type        = string
  default     = "Standard_B2s" # Or "Standard_DS1_v2" for slightly more consistent performance at low cost
}

variable "node_count" {
  description = "The number of worker nodes in the default node pool."
  type        = number
  default     = 1 # Changed from 2 to 1 for cost savings
}