# AKS Cluster and Kubernetes Dashboard Deployment with Terraform and Helm

---

This repository provides a fully automated solution to deploy an **Azure Kubernetes Service (AKS)** cluster on Azure, complete with its necessary networking infrastructure and the **Kubernetes Dashboard** for easy management. It leverages public modules from the Terraform Registry for robust and maintainable infrastructure as code.

---

## 🚀 Features

* **Automated Azure Infrastructure**: Provisions essential Azure resources, including a Resource Group, Virtual Network, and subnets, for a secure and scalable networking foundation.
* **AKS Cluster Deployment**: Sets up a managed AKS cluster with configurable node pools, including auto-scaling capabilities.
* **Kubernetes Dashboard Integration**: Deploys the official Kubernetes Dashboard via Helm, configured for external access (LoadBalancer) and initial administrative privileges.
* **Simplified Management**: Sets up a Service Account for dashboard access.
* **Modular and Reusable**: Leverages industry-standard Terraform modules for a clean, organized, and reusable infrastructure.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed and configured:

* **[Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)**: Configured with credentials that have sufficient permissions to create Azure resources (Resource Groups, AKS, Virtual Networks, etc.). You can log in using `az login`.
* **[Terraform](https://www.terraform.io/downloads.html)**: Version 1.0 or higher.
* **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)**: For interacting with the Kubernetes cluster after deployment.
* **[Helm](https://helm.sh/docs/intro/install/)**: For deploying applications to Kubernetes.

---

## 🚀 Getting Started

Follow these steps to deploy your AKS cluster and Kubernetes Dashboard:

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/aidynilyas/aks.git
    cd aks
    ```

2.  **Initialize Terraform**:
    This command downloads the necessary providers and modules.
    ```bash
    terraform init
    ```

3.  **Apply Terraform Configuration**:
    This will provision all the Azure resources and deploy the Kubernetes Dashboard. Review the plan and type `yes` to confirm.
    ```bash
    terraform apply
    ```

    This step will take about 20-25 minutes.

4.  **Verify Kubernetes Dashboard Deployment**:
    After `terraform apply` completes, check if the Kubernetes Dashboard service is running:
    ```bash
    kubectl get svc -n kubernetes-dashboard kubernetes-dashboard
    ```

5.  **Access the Kubernetes Dashboard (using `kubectl port-forward`)**:
    Open a new terminal and run the following command to create a secure tunnel to the dashboard:
    ```bash
    kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
    ```
    Now, open your web browser and navigate to: `https://localhost:8443`

6.  **Get the Bearer Token for Dashboard Login**:
    You'll need a token to log into the dashboard. Run the following command to retrieve the token for the `dashboard-admin-user` Service Account:

    **For Linux/macOS:**
    ```bash
    kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa dashboard-admin-user -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode
    ```

    **For Windows (PowerShell):**
    ```powershell
    $secretName = (kubectl -n kubernetes-dashboard get sa dashboard-admin-user -o jsonpath='{.secrets[0].name}')
    (kubectl -n kubernetes-dashboard get secret $secretName -o jsonpath='{.data.token}') | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
    ```
    Copy the outputted token and paste it into the Kubernetes Dashboard login page.

---

## 💡 Important Notes & Learnings

* **AKS Tiers and Support Plans**:
    * In certain Azure regions (e.g., US East, US West), the **Premium tier** for AKS clusters might be required or recommended for specific features or higher SLAs.
    * For **Long-Term Support (LTS) Kubernetes versions**, it's often necessary to specify `sku_tier` (e.g., `Premium`) and `support_plan` (e.g., `Standard` or `Premium`) in your Terraform configuration for the AKS cluster resource. This ensures you're leveraging the appropriate support model for your chosen Kubernetes version.

* **Kubernetes Dashboard Ingress**:
    While `kubectl port-forward` is convenient for local testing, in a production environment, you would typically use an Ingress Controller (like NGINX Ingress or Azure Application Gateway Ingress Controller) to expose the Kubernetes Dashboard securely via a domain name with HTTPS.

* **Bearer Token Security**:
    The method for obtaining the bearer token for the `dashboard-admin-user` provides full `cluster-admin` access. For production environments, it is highly recommended to implement more granular Role-Based Access Control (RBAC) and integrate with Azure Active Directory (AAD) for user authentication to the Kubernetes Dashboard, rather than relying solely on a service account token.

---

## 📁 Project Structure (AI Summary)

This Terraform code orchestrates the following automated steps to create an AKS cluster and deploy the Kubernetes Dashboard:

### `main.tf`

This file defines the Azure infrastructure and Kubernetes resources.

* **Azure Provider Configuration**:
    * `provider "azurerm"`: Configures the Azure provider for Terraform, specifying the deployment `features` for resource management.

* **Resource Group Module**:
    * `resource "azurerm_resource_group"`: Creates an Azure Resource Group to logically group all related resources.

* **Virtual Network and Subnets Module**:
    * `resource "azurerm_virtual_network"` and `resource "azurerm_subnet"`: Define the Virtual Network and subnets within Azure. This typically includes dedicated subnets for the AKS cluster's nodes.

* **AKS Cluster Module**:
    * `resource "azurerm_kubernetes_cluster"`: Provisions the Azure Kubernetes Service cluster.
    * Configures `name`, `location`, `resource_group_name`, and `kubernetes_version`.
    * Defines `default_node_pool` properties such as `node_count`, `vm_size`, and associates it with the created `subnet_id`.
    * Crucially, this is where `sku_tier` (e.g., `Premium`) and `support_plan` (e.g., `Standard`) are specified if required by the chosen Kubernetes version or region.
    * Configures `identity` (e.g., SystemAssigned or UserAssigned) for managed identities used by AKS.

* **Kubernetes Provider Configuration**:
    * `provider "kubernetes"`: Configures Terraform's Kubernetes provider to interact with the AKS cluster API. This provider uses the `host`, `client_certificate`, `client_key`, and `cluster_ca_certificate` dynamically obtained from the AKS cluster's outputs.

* **Helm Provider Configuration**:
    * `provider "helm"`: Configures Terraform's Helm provider, similarly authenticating with the AKS cluster's `kubernetes` endpoint.

* **Kubernetes Dashboard Deployment (Helm Release)**:
    * `resource "helm_release" "kubernetes_dashboard"`: Deploys the Dashboard using its official Helm chart (`kubernetes-dashboard` from `https://kubernetes.github.io/dashboard/`).
    * Creates a `kubernetes-dashboard` `namespace` and sets a `timeout` for deployment.
    * Configures `values` to expose the dashboard via a `LoadBalancer` (on `externalPort` 80 and `targetPort` 80) and sets `rbac.clusterAdminRole = true` for initial access.

* **Kubernetes Dashboard Admin User Setup**:
    * `resource "kubernetes_service_account_v1" "dashboard_admin"`: Creates a `dashboard-admin-user` Service Account within the dashboard's namespace.
    * `resource "kubernetes_cluster_role_binding_v1" "dashboard_admin_binding"`: Binds the `dashboard-admin-user` Service Account to the `cluster-admin` `ClusterRole` for full administrative access.

### `variables.tf`

This file defines input variables, allowing easy customization of the deployment:

* `resource_group_name` (default: `aks-dashboard-rg`)
* `location` (Azure region, e.g., `East US`)
* `aks_cluster_name` (default: `my-aks-dashboard-cluster`)
* `kubernetes_version` (e.g., `1.29.0`)
* `node_vm_size` (e.g., `Standard_DS2_v2`)
* `node_count` (desired number of nodes)
* `sku_tier` (e.g., `Premium`, if required for LTS versions or specific regions)
* `support_plan` (e.g., `Standard`, if required)

---

## 💡 Overall Process Flow

This Terraform code orchestrates the following automated steps:

1.  **Azure Infrastructure Provisioning**: A new Azure Resource Group, Virtual Network, and subnets are created to host the AKS cluster, providing a logically isolated and secure network environment.
2.  **AKS Cluster Creation**: An Azure Kubernetes Service (AKS) cluster is provisioned within the created network. This includes setting up the control plane and a default node pool (worker nodes) configured with the specified VM size, node count, and importantly, the correct SKU tier and support plan to meet requirements for LTS Kubernetes versions or specific regions.
3.  **Kubernetes and Helm Provider Configuration**: Once AKS is ready, Terraform configures its `kubernetes` and `helm` providers. These providers authenticate with the AKS cluster's API server using credentials dynamically obtained from the AKS cluster's outputs.
4.  **Kubernetes Dashboard Deployment via Helm**: The official Kubernetes Dashboard is deployed via Helm, configured with a dedicated namespace, exposed via an Azure Load Balancer, and initially configured with `cluster-admin` RBAC permissions for easy setup.
5.  **Dashboard Admin User Setup**: A `dashboard-admin-user` Kubernetes Service Account is created and bound to the `cluster-admin` ClusterRole, providing an authentication token that can be used to log into the dashboard.

This complete, automated solution allows you to quickly spin up a functional AKS cluster with a management dashboard, streamlining your Kubernetes development and operations on Azure.
