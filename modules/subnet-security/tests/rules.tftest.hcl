# AgentAlvine | Same guardrail cases as the public API, testing var.rules directly.
# MOCK ONLY. Each rejection changes one property of an otherwise valid rule.
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
  rules = {
    allow-private-https = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.42.1.0/24"
      destination_address_prefix = "10.42.2.0/24"
    }
  }
}

run "reject_invalid_priority" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { priority = 99 }) }
  }
  expect_failures = [var.rules]
}

run "reject_priority_above_limit" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { priority = 4097 }) }
  }
  expect_failures = [var.rules]
}

run "reject_fractional_priority" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { priority = 100.5 }) }
  }
  expect_failures = [var.rules]
}

run "reject_duplicate_priorities" {
  command = plan
  variables {
    rules = {
      first  = var.rules["allow-private-https"]
      second = merge(var.rules["allow-private-https"], { destination_port_range = "8443" })
    }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_direction" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { direction = "inbound" }) }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_access" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { access = "Permit" }) }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_protocol" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { protocol = "HTTP" }) }
  }
  expect_failures = [var.rules]
}

run "reject_invalid_rule_name" {
  command = plan
  variables {
    rules = { "bad name" = var.rules["allow-private-https"] }
  }
  expect_failures = [var.rules]
}

run "reject_port_above_limit" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { destination_port_range = "65536" }) }
  }
  expect_failures = [var.rules]
}

run "reject_reversed_port_range" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { destination_port_range = "445-443" }) }
  }
  expect_failures = [var.rules]
}

run "reject_source_port_list" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_port_range = "80,443" }) }
  }
  expect_failures = [var.rules]
}

run "reject_icmp_with_tcp_port" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { protocol = "Icmp" }) }
  }
  expect_failures = [var.rules]
}

run "reject_internet_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "Internet" }) }
  }
  expect_failures = [var.rules]
}

run "reject_ipv4_default_route_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "0.0.0.0/0" }) }
  }
  expect_failures = [var.rules]
}

run "reject_ipv4_host_bits_default_route_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "1.2.3.4/0" }) }
  }
  expect_failures = [var.rules]
}

run "reject_ipv6_default_route_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "::/0" }) }
  }
  expect_failures = [var.rules]
}

run "reject_expanded_ipv6_default_route_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "0000:0000:0000:0000:0000:0000:0000:0000/0" }) }
  }
  expect_failures = [var.rules]
}

run "reject_virtualnetwork_service_tag_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "VirtualNetwork" }) }
  }
  expect_failures = [var.rules]
}

run "reject_public_cidr_ingress" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "203.0.113.0/24" }) }
  }
  expect_failures = [var.rules]
}

run "reject_cidr_spanning_private_and_public_space" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { source_address_prefix = "172.16.0.0/11" }) }
  }
  expect_failures = [var.rules]
}

run "reject_malformed_destination_cidr" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { destination_address_prefix = "10.42.2.0/33" }) }
  }
  expect_failures = [var.rules]
}

run "reject_overlong_description" {
  command = plan
  variables {
    rules = { invalid = merge(var.rules["allow-private-https"], { description = join("", [for index in range(141) : "x"]) }) }
  }
  expect_failures = [var.rules]
}

run "valid_same_priority_in_opposite_directions" {
  command = plan
  variables {
    rules = {
      inbound  = var.rules["allow-private-https"]
      outbound = merge(var.rules["allow-private-https"], { direction = "Outbound", access = "Deny", source_address_prefix = "*", destination_address_prefix = "Internet" })
    }
  }
}

run "valid_rfc1918_and_port_boundaries" {
  command = plan
  variables {
    rules = {
      private-ten = merge(var.rules["allow-private-https"], {
        source_address_prefix  = "10.0.0.0/8"
        source_port_range      = "0-65535"
        destination_port_range = "443-445"
      })
      private-172 = merge(var.rules["allow-private-https"], { priority = 101, source_address_prefix = "172.16.0.0/12" })
      private-192 = merge(var.rules["allow-private-https"], { priority = 4096, source_address_prefix = "192.168.0.0/16", destination_port_range = "65535" })
    }
  }
}

run "valid_explicit_deny_internet_ingress" {
  command = plan
  variables {
    rules = { deny-internet = merge(var.rules["allow-private-https"], { access = "Deny", source_address_prefix = "Internet" }) }
  }
}
