terraform {
  backend "azurerm" {
    resource_group_name  = "rg-wber-euw"
    storage_account_name = "tfstatewberhault"
    container_name       = "wber-container"
    key                  = "terraform.tfstate"
  }
}