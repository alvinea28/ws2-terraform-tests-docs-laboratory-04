# AgentAlvine | Complete child-reference wiring. MOCK ONLY, all commands plan.
mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

override_resource {
  target          = azurerm_subnet_network_security_group_association.this["web"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
  }
}

override_resource {
  target          = azurerm_subnet_network_security_group_association.this["data"]
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/data"
  }
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

run "safe_empty_custom_rules" {
  command = plan

  assert {
    condition     = length(azurerm_network_security_rule.this) == 0
    error_message = "The default must create no custom rules; Azure defaults are not a zero-trust policy."
  }

  assert {
    condition = (
      azurerm_network_security_group.this.name == var.name &&
      azurerm_network_security_group.this.location == var.location &&
      azurerm_network_security_group.this.resource_group_name == var.resource_group_name &&
      azurerm_network_security_group.this.tags == var.tags &&
      output.nsg_id == azurerm_network_security_group.this.id
    )
    error_message = "The NSG must use only the injected name, existing group, region and tags."
  }

  assert {
    condition = toset(keys(azurerm_subnet_network_security_group_association.this)) == toset(["data", "web"]) && alltrue([
      for name, association in azurerm_subnet_network_security_group_association.this :
      association.subnet_id == var.subnet_ids[name] && association.network_security_group_id == output.nsg_id
    ])
    error_message = "Associate each injected subnet ID with this NSG using the caller's stable keys."
  }

  assert {
    condition     = output.association_ids == var.subnet_ids
    error_message = "AzureRM association IDs are the subnet IDs and must be returned under their original keys."
  }
}

run "valid_rule_wiring" {
  command = plan
  variables {
    rules = {
      allow-private-https = {
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        destination_port_range     = "443"
        source_address_prefix      = "10.42.1.0/24"
        destination_address_prefix = "10.42.2.0/24"
        description                = "HTTPS from the explicit web subnet to the data subnet."
      }
    }
  }

  assert {
    condition     = toset(keys(azurerm_network_security_rule.this)) == toset(["allow-private-https"])
    error_message = "Create exactly the named standalone custom rule."
  }

  assert {
    condition = alltrue([
      for name, rule in azurerm_network_security_rule.this :
      rule.name == name &&
      rule.network_security_group_name == var.name &&
      rule.resource_group_name == var.resource_group_name &&
      rule.priority == var.rules[name].priority &&
      rule.direction == var.rules[name].direction &&
      rule.access == var.rules[name].access &&
      rule.protocol == var.rules[name].protocol &&
      rule.source_port_range == "*" &&
      rule.destination_port_range == var.rules[name].destination_port_range &&
      rule.source_address_prefix == var.rules[name].source_address_prefix &&
      rule.destination_address_prefix == var.rules[name].destination_address_prefix &&
      rule.description == var.rules[name].description
    ])
    error_message = "Pass every rule argument to AzureRM unchanged; the optional source port defaults to *."
  }

  assert {
    condition     = output.association_ids == var.subnet_ids
    error_message = "Adding an approved rule must not change subnet association identity."
  }
}
