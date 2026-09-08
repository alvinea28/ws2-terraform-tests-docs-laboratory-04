# AgentAlvine | Complete-reference wiring checks supplement the public API suite.
# MOCK ONLY. Only computed IDs are overridden; configured resource arguments
# and the real child-module implementation remain under test.
mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

override_resource {
  target          = azurerm_subnet.this["web"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
  }
}

override_resource {
  target          = azurerm_subnet.this["data"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/data"
  }
}

override_resource {
  target          = module.security.azurerm_subnet_network_security_group_association.this["web"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
  }
}

override_resource {
  target          = module.security.azurerm_subnet_network_security_group_association.this["data"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/data"
  }
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

run "complete_topology_wiring" {
  command = plan

  assert {
    condition = (
      azurerm_virtual_network.this.name == var.name &&
      azurerm_virtual_network.this.resource_group_name == var.resource_group_name &&
      azurerm_virtual_network.this.location == var.location &&
      toset(azurerm_virtual_network.this.address_space) == toset(var.address_space) &&
      azurerm_virtual_network.this.tags == var.tags &&
      output.vnet_id == azurerm_virtual_network.this.id
    )
    error_message = "The VNet must use the caller's name, existing group, region, address space and tags, and expose its ID."
  }

  assert {
    condition = toset(keys(azurerm_subnet.this)) == toset(["data", "web"]) && alltrue([
      for name, subnet in azurerm_subnet.this :
      subnet.name == name &&
      subnet.resource_group_name == var.resource_group_name &&
      subnet.virtual_network_name == azurerm_virtual_network.this.name &&
      toset(subnet.address_prefixes) == toset(var.subnets[name].address_prefixes) &&
      subnet.default_outbound_access_enabled == false
    ])
    error_message = "Standalone subnets must retain stable keys and requested prefixes, belong to this VNet, and disable default outbound access."
  }

  assert {
    condition = output.subnet_ids == tomap({
      web  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
      data = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/data"
    })
    error_message = "Each output key must expose its own subnet resource ID, not a duplicate or positional ID."
  }

  assert {
    condition     = output.association_ids == output.subnet_ids && output.association_ids == module.security.association_ids && output.nsg_id == module.security.nsg_id
    error_message = "Expose the actual child-module outputs and preserve every subnet association key."
  }
}
