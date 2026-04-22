resource "azurerm_linux_virtual_machine" "k8s" {
  count               = var.vm_count
  name                = count.index == 0 ? "k8s-control-plane" : "k8s-worker-${count.index}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  size                = var.vm_size
  admin_username      = var.admin_username

#   priority = "Spot"
#   eviction_policy = "Deallocate"
#   max_bid_price = -1

  network_interface_ids = [
    azurerm_network_interface.k8s[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}