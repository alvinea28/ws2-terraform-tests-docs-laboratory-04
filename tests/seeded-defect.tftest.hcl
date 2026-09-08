# AgentAlvine | Isolated regression used by the seeded-defect demonstration.
# A missing expected failure here, not an arbitrary nonzero exit, proves the defect.
# MOCK ONLY. This file must never contain a real provider or alternate module.
mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  name                = "vnet-ws2-mock"
  resource_group_name = "rg-ws2-mock"
  location            = "westeurope"
  address_space       = ["10.42.0.0/16"]
  subnets = {
    web  = { address_prefixes = ["10.42.1.0/24"] }
    data = { address_prefixes = ["10.42.2.0/24"] }
  }
  tags = {
    owner       = "workshop-team"
    environment = "dev"
    cost_center = "training"
    workshop    = "ws2"
  }
}

run "reject_wildcard_ingress" {
  command = plan
  variables {
    security_rules = {
      prohibited-public-https = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "10.42.2.0/24"
      }
    }
  }
  expect_failures = [var.security_rules]
}
