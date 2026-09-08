# AgentAlvine | Isolated child ingress regression. MOCK ONLY, no alternate module.
mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  name                = "vnet-ws2-mock-nsg"
  resource_group_name = "rg-ws2-mock"
  location            = "westeurope"
  subnet_ids = {
    web  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
    data = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/data"
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
    rules = {
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
  expect_failures = [var.rules]
}
