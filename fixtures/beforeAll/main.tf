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

resource "azurerm_resource_group" "test" {
  name     = "auto-test-deployifnot-${random_string.suffix.result}"
  location = "westeurope"
}

resource "azurerm_log_analytics_workspace" "test" {
  name                = "auto-test-la-${random_string.suffix.result}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  sku                 = "PerGB2018"
}

data "azurerm_policy_definition" "deploy_kv_diag_setting" {
  display_name = "Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace"
}

resource "azurerm_resource_group_policy_assignment" "test" {
  description  = "test the deploy if not exist behavior"
  display_name = "test the deploy if not exist behavior"
  identity {
    type = "SystemAssigned"
  }
  location             = azurerm_resource_group.test.location
  name                 = "test the deploy if not exist behavior"
  policy_definition_id = data.azurerm_policy_definition.deploy_kv_diag_setting.id
  resource_group_id    = azurerm_resource_group.test.id
  parameters = jsonencode({
    effect                      = { value = "DeployIfNotExists" }
    logAnalytics                = { value = azurerm_log_analytics_workspace.test.id }
    diagnosticsSettingNameToUse = { value = "AutoTestDiagnosticSetting" }
    AllMetricsEnabled           = { value = "False" }
    AuditEventEnabled           = { value = "True" }
  })
}

resource "azurerm_role_assignment" "msi_log_analytics_contributor_on_rg" {
  scope                = azurerm_resource_group.test.id
  principal_id         = azurerm_resource_group_policy_assignment.test.identity.0.principal_id
  role_definition_name = "Log Analytics Contributor"
}


resource "azurerm_role_assignment" "msi_monitoring_contributor_on_rg" {
  scope                = azurerm_resource_group.test.id
  principal_id         = azurerm_resource_group_policy_assignment.test.identity.0.principal_id
  role_definition_name = "Monitoring Contributor"
}

output "resource_group_name" {
  value = azurerm_resource_group.test.name
}
