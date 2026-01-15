# Azure Kubernetes Service (AKS) Cluster
# Terraform configuration for Internal Developer Platform

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateplatform"
    container_name       = "tfstate"
    key                  = "idp.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "idp" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    environment = var.environment
    project     = "internal-developer-platform"
    managed_by  = "terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "idp" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.idp.location
  resource_group_name = azurerm_resource_group.idp.name
  address_space       = ["10.0.0.0/16"]
  
  tags = azurerm_resource_group.idp.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.idp.name
  virtual_network_name = azurerm_virtual_network.idp.name
  address_prefixes     = ["10.0.1.0/24"]
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "idp" {
  name                = var.cluster_name
  location            = azurerm_resource_group.idp.location
  resource_group_name = azurerm_resource_group.idp.name
  dns_prefix          = var.cluster_name
  
  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
    
    tags = azurerm_resource_group.idp.tags
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }
  
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.idp.id
  }
  
  tags = azurerm_resource_group.idp.tags
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "idp" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.idp.location
  resource_group_name = azurerm_resource_group.idp.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = azurerm_resource_group.idp.tags
}

# Container Registry
resource "azurerm_container_registry" "idp" {
  name                = replace(var.cluster_name, "-", "")
  resource_group_name = azurerm_resource_group.idp.name
  location            = azurerm_resource_group.idp.location
  sku                 = "Standard"
  admin_enabled       = false
  
  tags = azurerm_resource_group.idp.tags
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.idp.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.idp.id
  skip_service_principal_aad_check = true
}
