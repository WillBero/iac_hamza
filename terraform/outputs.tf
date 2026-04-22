output "control_plane_ip" {
  value       = azurerm_public_ip.k8s[0].ip_address
  description = "IP publique du control plane"
}

output "worker_ips" {
  value       = [for i in range(1, var.vm_count) : azurerm_public_ip.k8s[i].ip_address]
  description = "IPs publiques des workers"
}

output "all_ips" {
  value = [for pip in azurerm_public_ip.k8s : pip.ip_address]
}