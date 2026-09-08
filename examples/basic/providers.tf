# AgentAlvine | This example is a consumer root, not part of the module contract.
# Subscription selection (ARM_SUBSCRIPTION_ID) and approved authentication are
# external prerequisites. Do not put credentials or subscription IDs in HCL.
# Provider registration is instructor-owned. This example owns no backend or RG.
provider "azurerm" {
  resource_provider_registrations = "none"

  features {}
}
