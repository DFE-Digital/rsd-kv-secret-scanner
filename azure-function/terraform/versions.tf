terraform {
  required_version = ">= 1.7.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.87.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.37.1"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.12.1"
    }
  }
}
