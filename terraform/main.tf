terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://your-proxmox-server:8006/api2/json"
  pm_user = "your-proxmox-username@pam"
  pm_password = "your-proxmox-password"
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "monitoring_vm" {
  count = 1
  name = "monitoring-vm-${count.index + 1}"
  target_node = "your-proxmox-node"
  clone = "ubuntu-monitoring-template"
  
  cores = 2
  sockets = 1
  cpu = "host"
  memory = 4096
  
  network {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  disk {
    type = "virtio"
    storage = "local-lvm"
    size = "20G"
  }

  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"

  depends_on = [null_resource.packer_build]
}

output "vm_ip_addresses" {
  value = proxmox_vm_qemu.monitoring_vm[*].default_ipv4_address
}