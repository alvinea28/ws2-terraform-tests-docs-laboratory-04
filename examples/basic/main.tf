# AgentAlvine | D1.6: consume the public package, not its internal resources.
# The local source demonstrates external-to-package use from a separate root.
# The learner package stays intentionally unfinished until D1.3-D1.4 are done.
# No live operation is authorized by this example; use the protected consumer
# repository for instructor-approved Azure work and remote state.
module "network" {
  source = "../.."

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  subnets             = var.subnets
  tags                = var.tags
  security_rules      = var.security_rules
}
