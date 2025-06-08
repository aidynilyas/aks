# main.tf

# Configure the Azure Resource Manager (Azurerm) Provider
provider "azurerm" {
  features {} # Required for Azurerm Provider 2.x and above
}

# --- Azure Resource Group ---
# A resource group is a container that holds related resources for an Azure solution.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Dev"
    Project     = "KubernetesDashboard"
  }
}

# --- Azure Virtual Network and Subnet ---
# Create a dedicated Virtual Network and a subnet for the AKS cluster.
resource "azurerm_virtual_network" "main" {
  name                = "${var.aks_cluster_name}-vnet"
  address_space       = ["10.0.0.0/16"] # Your VNet CIDR
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"] # Your Subnet CIDR
}

# --- Azure Kubernetes Service (AKS) Cluster ---
# Provisions the AKS cluster.
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.aks_cluster_name}-dns"

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    # Associate the node pool with the created subnet
    vnet_subnet_id = azurerm_subnet.internal.id
  }

  # Service Principal or Managed Identity for AKS cluster
  # For simplicity, we are using a system-assigned managed identity.
  # In production, consider user-assigned managed identity for better control.
  identity {
    type = "SystemAssigned"
  }

  # IMPORTANT: Setting the SKU Tier to 'Premium' and 'AKSLongTermSupport'
  # This is required for deploying Kubernetes versions designated as LTS in Azure.
  # Be aware that the Premium tier incurs additional costs.
  sku_tier     = "Premium"
  support_plan = "AKSLongTermSupport"

  # --- Network Profile for AKS Cluster ---
  # Define the network settings for the AKS cluster,
  # including a service CIDR that does NOT overlap with the VNet.
  network_profile {
    network_plugin     = "azure" # Recommended for most AKS deployments
    service_cidr       = "172.16.0.0/20" # Non-overlapping CIDR for Kubernetes services
    dns_service_ip     = "172.16.0.10" # IP for Kubernetes DNS service within the service CIDR
    # docker_bridge_cidr is deprecated and removed to avoid warnings
  }

  tags = {
    Environment = "Dev"
    Project     = "KubernetesDashboard"
  }
}

# --- Locals for Kubeconfig Parsing ---
# Parse the raw kubeconfig YAML into a Terraform object for easier access
locals {
  kube_config = yamldecode(azurerm_kubernetes_cluster.main.kube_config_raw)
  # Extract cluster details from the parsed kubeconfig
  kube_cluster = try(local.kube_config.clusters[0].cluster, {})
  # Extract user details (specifically the client certificate/key and token if present)
  # AKS's kube_config_raw typically contains client cert/key or exec auth
  kube_user    = try(local.kube_config.users[0].user, {})
}

# --- Kubernetes Provider Configuration ---
# The Kubernetes provider needs to authenticate with the AKS cluster.
# We extract specific values from the parsed kubeconfig.
provider "kubernetes" {
  # Use the server endpoint from the parsed kubeconfig
  host                   = local.kube_cluster.server
  # Use the certificate authority data from the parsed kubeconfig
  cluster_ca_certificate = base64decode(local.kube_cluster.certificate-authority-data)
  # Use the client certificate data if available
  client_certificate     = try(base64decode(local.kube_user.client-certificate-data), null)
  # Use the client key data if available
  client_key             = try(base64decode(local.kube_user.client-key-data), null)
  # For AKS, it often uses an 'exec' plugin for token generation,
  # so we rely on the host, CA, and client cert/key provided in the raw config.
  # If an explicit token is needed for the provider, it would be 'token = local.kube_user.token'
}

# --- Helm Provider Configuration ---
# The Helm provider also needs to authenticate with the AKS cluster.
provider "helm" {
  kubernetes {
    # Use the server endpoint from the parsed kubeconfig
    host                   = local.kube_cluster.server
    # Use the certificate authority data from the parsed kubeconfig
    cluster_ca_certificate = base64decode(local.kube_cluster.certificate-authority-data)
    # Use the client certificate data if available
    client_certificate     = try(base64decode(local.kube_user.client-certificate-data), null)
    # Use the client key data if available
    client_key             = try(base64decode(local.kube_user.client-key-data), null)
    # Similar to Kubernetes provider, rely on the exec plugin for authentication
  }
}

# --- Kubernetes Dashboard Deployment ---
# Deploy the Kubernetes Dashboard using its official Helm chart.
# This part is largely the same as the EKS configuration, as it interacts
# directly with the Kubernetes API.
resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  namespace  = "kubernetes-dashboard"
  create_namespace = true
  timeout    = 600 # Increased timeout for potential provisioning delays

  values = [
    yamlencode({
      service = {
        # For AKS, LoadBalancer type provisions an Azure Load Balancer.
        # It's common to use an Ingress controller for external access in production.
        # We set http protocol for simpler access via kubectl proxy.
        type = "LoadBalancer"
        externalPort = 80
        targetPort = 80
      }
      rbac = {
        create = true
        clusterAdminRole = true # Grants cluster-admin permissions to the service account
      }
      ingress = {
        enabled = false # We'll use kubectl proxy for access in this guide
      }
    })
  ]
}

# --- Kubernetes Dashboard Admin User Setup ---
# Create a ServiceAccount and ClusterRoleBinding for an admin user
# to authenticate with the Kubernetes Dashboard.
resource "kubernetes_service_account_v1" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin-user"
    namespace = helm_release.kubernetes_dashboard.namespace
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_admin_binding" {
  metadata {
    name = "dashboard-admin-user-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Bind to cluster-admin for full access
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account_v1.dashboard_admin.metadata[0].namespace
  }
}
