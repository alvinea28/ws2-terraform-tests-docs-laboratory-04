mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  name                = "ws2-network"
  resource_group_name = "rg-ws2-existing"
  location            = "southeastasia"
  address_space       = ["10.42.0.0/16"]
  subnets = {
    web  = { address_prefixes = ["10.42.1.0/24"] }
    data = { address_prefixes = ["10.42.2.0/24"] }
  }
  tags = { owner = "team", environment = "dev", cost_center = "training", workshop = "ws2" }
}

run "learner_valid_subnets" {
  command = plan
  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["web", "data"])
    error_message = "Both named subnets must be present."
  }
}

run "learner_reject_invalid_cidr" {
  command = plan
  variables {
    address_space = ["not-a-cidr"]
  }
  expect_failures = [var.address_space]
}
