# AgentAlvine | D1.3-D1.5 public API tests. The learner's empty outputs fail
# assertions, not parsing or references to resources that do not exist yet.
# MOCK ONLY: all runs plan against a mock provider, never Azure or remote state.
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

run "valid_two_subnet_topology" {
  command = plan

  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["data", "web"])
    error_message = "Return exactly the two caller-supplied stable subnet keys, data and web."
  }

  assert {
    condition     = toset(keys(output.association_ids)) == toset(["data", "web"])
    error_message = "Compose subnet-security and return an association for each named subnet."
  }

  assert {
    condition     = output.vnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock"
    error_message = "vnet_id must expose the VNet resource's mocked Azure ID, not an empty value."
  }

  assert {
    condition     = output.nsg_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/networkSecurityGroups/vnet-ws2-mock-nsg"
    error_message = "nsg_id must expose the composed security module's mocked NSG ID."
  }

  assert {
    condition = alltrue([
      for id in concat(values(output.subnet_ids), values(output.association_ids)) :
      can(regex("^/subscriptions/[0-9a-f-]{36}/resourceGroups/rg-ws2-mock/providers/Microsoft\\.Network/virtualNetworks/vnet-ws2-mock/subnets/[^/]+$", id))
    ])
    error_message = "Subnet and association outputs must contain realistic Azure subnet IDs."
  }
}

run "valid_narrow_inbound" {
  command = plan

  variables {
    security_rules = {
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
    condition     = toset(keys(output.subnet_ids)) == toset(["data", "web"]) && toset(keys(output.association_ids)) == toset(["data", "web"])
    error_message = "A valid private HTTPS rule must preserve both named subnet/association maps."
  }
}

run "reject_invalid_vnet_cidr" {
  command = plan
  variables {
    address_space = ["10.300.0.0/16"]
  }
  expect_failures = [var.address_space]
}

run "reject_ipv6_vnet_cidr" {
  command = plan
  variables {
    address_space = ["fd00::/48"]
  }
  expect_failures = [var.address_space]
}

run "reject_empty_address_space" {
  command = plan
  variables {
    address_space = []
  }
  expect_failures = [var.address_space]
}

run "reject_invalid_subnet_cidr" {
  command = plan
  variables {
    subnets = { web = { address_prefixes = ["10.42.1.0/33"] } }
  }
  expect_failures = [var.subnets]
}

run "reject_ipv6_subnet_cidr" {
  command = plan
  variables {
    subnets = { web = { address_prefixes = ["fd00::/64"] } }
  }
  expect_failures = [var.subnets]
}

run "reject_empty_subnet_prefixes" {
  command = plan
  variables {
    subnets = { web = { address_prefixes = [] } }
  }
  expect_failures = [var.subnets]
}

run "reject_empty_subnets" {
  command = plan
  variables {
    subnets = {}
  }
  expect_failures = [var.subnets]
}

run "reject_unstable_subnet_name" {
  command = plan
  variables {
    subnets = { "web subnet" = { address_prefixes = ["10.42.1.0/24"] } }
  }
  expect_failures = [var.subnets]
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
    tags = merge(var.tags, { owner = " \t " })
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
