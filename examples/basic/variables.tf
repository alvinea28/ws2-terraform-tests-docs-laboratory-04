variable "name" {
  description = "Caller-selected VNet name following the module's naming contract."
  type        = string
  nullable    = false
}

variable "resource_group_name" {
  description = "Existing instructor-managed workload group; this example never creates or looks it up."
  type        = string
  nullable    = false
}

variable "location" {
  description = "Instructor-approved Azure region."
  type        = string
  nullable    = false
}

variable "address_space" {
  description = "Approved IPv4 address space; the module checks CIDR syntax, not allocation/overlap."
  type        = list(string)
  nullable    = false
}

variable "subnets" {
  description = "Subnet definitions keyed by stable names; the caller controls additions."
  type = map(object({
    address_prefixes = list(string)
  }))
  nullable = false
}

variable "tags" {
  description = "Nonblank owner, environment, cost_center and workshop tags, plus optional nonblank tags."
  type        = map(string)
  nullable    = false
}

variable "security_rules" {
  description = "Optional custom rules. Inbound Allow needs an explicit IPv4 RFC1918 source; empty rules preserve Azure NSG defaults, including internal VirtualNetwork access."
  type = map(object({
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = optional(string, "*")
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = optional(string, "")
  }))
  default  = {}
  nullable = false
}
