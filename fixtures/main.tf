terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
  number  = false
}

variable "resource_group_name" {
  type = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "test" {
  enable_rbac_authorization  = true
  name                       = "autotestdeploykv${random_string.suffix.result}"
  resource_group_name        = var.resource_group_name
  location                   = "westeurope"
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tenant_id                  = data.azurerm_client_config.current.tenant_id
}

output "vault_id" {
  value = azurerm_key_vault.test.id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}
