## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | = 1.16.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | = 5.4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 5.4.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_security"></a> [security](#module\_security) | ./modules/subnet-security | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.4.0/docs/resources/subnet) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.4.0/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | Nonempty list of IPv4 VNet CIDRs. Syntax is checked; containment, overlap, Azure size limits and organizational allocation remain caller/preflight responsibilities. | `list(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region selected by the caller; resource-provider registration and regional/policy readiness are instructor prerequisites. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Virtual-network name: 1-64 lowercase letters, digits or hyphens, starting with a letter and ending with a letter/digit. The NSG appends -nsg. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing, instructor-managed workload resource group. This module never creates or looks up the group. | `string` | n/a | yes |
| <a name="input_security_rules"></a> [security\_rules](#input\_security\_rules) | Custom NSG rules keyed by stable rule names. Empty by default: Azure default rules still allow VirtualNetwork/AzureLoadBalancer inbound before default deny. Inbound Allow sources must be explicit IPv4 CIDRs wholly inside RFC1918; no public/IPv6 sources or service tags. Other prefixes accept CIDRs, *, VirtualNetwork, AzureLoadBalancer or Internet. This is not zero trust or an egress policy. | <pre>map(object({<br/>    priority                   = number<br/>    direction                  = string<br/>    access                     = string<br/>    protocol                   = string<br/>    source_port_range          = optional(string, "*")<br/>    destination_port_range     = string<br/>    source_address_prefix      = string<br/>    destination_address_prefix = string<br/>    description                = optional(string, "")<br/>  }))</pre> | `{}` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Nonempty map of subnet objects keyed by stable Azure subnet names (lowercase letters/digits/hyphens, 1-80 characters). Adding a key does not renumber existing resources. | <pre>map(object({<br/>    address_prefixes = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | VNet/NSG tags. owner, environment, cost\_center and workshop are required; every supplied tag key/value must be nonblank. Subnets and associations do not support tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_association_ids"></a> [association\_ids](#output\_association\_ids) | NSG association IDs keyed by subnet name; Azure uses the subnet ID for each association. |
| <a name="output_nsg_id"></a> [nsg\_id](#output\_nsg\_id) | Azure resource ID of the composed network security group. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet resource IDs keyed by the caller's stable subnet names. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | Azure resource ID of the virtual network. |
