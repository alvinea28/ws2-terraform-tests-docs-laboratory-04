output "vnet_id" {
  description = "VNet ID from the public module API."
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by the caller's names."
  value       = module.network.subnet_ids
}

output "nsg_id" {
  description = "NSG ID from the public module API."
  value       = module.network.nsg_id
}

output "association_ids" {
  description = "NSG association IDs keyed by subnet name."
  value       = module.network.association_ids
}
