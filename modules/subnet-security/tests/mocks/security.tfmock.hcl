# AgentAlvine | Inert Azure-shaped fixtures, not credentials or live resources.
# Exact per-subnet association identity is checked separately in the checkpoints.
mock_resource "azurerm_network_security_group" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/networkSecurityGroups/vnet-ws2-mock-nsg"
  }
}

mock_resource "azurerm_network_security_rule" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/networkSecurityGroups/vnet-ws2-mock-nsg/securityRules/allow-private-https"
  }
}

mock_resource "azurerm_subnet_network_security_group_association" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ws2-mock/providers/Microsoft.Network/virtualNetworks/vnet-ws2-mock/subnets/web"
  }
}
