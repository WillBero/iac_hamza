variable "subscription_id" { type = string }
variable "client_id"       { type = string }
variable "client_secret"   { type = string }
variable "tenant_id"       { type = string }

variable "location" {
  type    = string
  default = "West Europe"
}

variable "vm_count" {
  type    = number
  default = 3
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}