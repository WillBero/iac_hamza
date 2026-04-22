resource "azurerm_resource_group" "k8s" {
  name     = "rg-wber-euw"
  location = var.location
}

resource "azurerm_virtual_network" "k8s" {
  name                = "wber-vnet"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "k8s" {
  name                 = "wber-subnet"
  resource_group_name  = azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "k8s" {
  name                = "wber-nsg"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "wber-API"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Internal"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "k8s" {
  count               = var.vm_count
  name                = "wber-pip-${count.index}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "k8s" {
  count               = var.vm_count
  name                = "wber-nic-${count.index}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.k8s[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "k8s" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.k8s[count.index].id
  network_security_group_id = azurerm_network_security_group.k8s.id
}