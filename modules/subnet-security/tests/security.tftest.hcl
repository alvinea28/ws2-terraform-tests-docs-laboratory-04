# AgentAlvine | Standalone child-module API tests: no baseline module or lookups.
# MOCK ONLY. Empty learner outputs fail assertions instead of invalid references.
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

run "valid_two_subnet_associations" {
  command = plan

  assert {
    condition     = toset(keys(output.association_ids)) == toset(["data", "web"])
    error_message = "Return exactly one association per caller-supplied stable subnet key."
  }

  assert {
    condition     = output.nsg_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/networkSecurityGroups/vnet-ws2-mock-nsg"
    error_message = "nsg_id must expose the NSG resource's mocked Azure ID, not an empty string."
  }

  assert {
    condition = alltrue([
      for id in values(output.association_ids) :
      can(regex("^/subscriptions/[0-9a-f-]{36}/resourceGroups/rg-ws2-mock/providers/Microsoft\\.Network/virtualNetworks/vnet-ws2-mock/subnets/[^/]+$", id))
    ])
    error_message = "Association IDs must use realistic Azure subnet-ID shapes."
  }
}

run "valid_narrow_inbound" {
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
      }
    }
  }

  assert {
    condition     = toset(keys(output.association_ids)) == toset(["data", "web"])
    error_message = "A valid private HTTPS rule must retain both named subnet associations."
  }
}

run "reject_empty_subnet_ids" {
  command = plan
  variables {
    subnet_ids = {}
  }
  expect_failures = [var.subnet_ids]
}

run "reject_invalid_subnet_id" {
  command = plan
  variables {
    subnet_ids = { web = "not-an-azure-id" }
  }
  expect_failures = [var.subnet_ids]
}

run "reject_vnet_id_instead_of_subnet_id" {
  command = plan
  variables {
    subnet_ids = { web = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock" }
  }
  expect_failures = [var.subnet_ids]
}

run "reject_unstable_subnet_key" {
  command = plan
  variables {
    subnet_ids = { "web subnet" = var.subnet_ids.web }
  }
  expect_failures = [var.subnet_ids]
}

run "reject_missing_tags" {
  command = plan
  variables {
    tags = { owner = "team", environment = "dev", workshop = "ws2" }
  }
  expect_failures = [var.tags]
}

run "reject_blank_required_tag" {
  command = plan
  variables {
    tags = merge(var.tags, { cost_center = " \t " })
  }
  expect_failures = [var.tags]
}

run "reject_null_required_tag" {
  command = plan
  variables {
    tags = merge(var.tags, { owner = null })
  }
  expect_failures = [var.tags]
}

run "reject_blank_extra_tag" {
  command = plan
  variables {
    tags = merge(var.tags, { extra = " " })
  }
  expect_failures = [var.tags]
}

run "reject_blank_resource_group" {
  command = plan
  variables {
    resource_group_name = " "
  }
  expect_failures = [var.resource_group_name]
}

run "reject_blank_location" {
  command = plan
  variables {
    location = " "
  }
  expect_failures = [var.location]
}

run "reject_invalid_name" {
  command = plan
  variables {
    name = "not a name"
  }
  expect_failures = [var.name]
}
