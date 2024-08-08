# Ubuntu Server 
# ---
# Packer Template to create an Ubuntu Server with Grafana, Telegraf, and Proxmox installed

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu-monitoring" {
  proxmox_url              = "https://your-ip-address:8006/api2/json"
  username                 = "your-user-name"
  token                    = "your-token"
  # (Optional) Skip TLS Verification
  insecure_skip_tls_verify = true

  node                     = "proxnetwork"
  iso_file                 = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"
  unmount_iso              = true
  qemu_agent               = true

  scsi_controller          = "virtio-scsi-pci"

  disks {
    disk_size         = "20G"
    format            = "raw"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "virtio"
  }

  cores                    = "2"
  memory                   = "4096"

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
  }

  cloud_init               = true
  cloud_init_storage_pool  = "local-lvm"

  template_name            = "ubuntu-monitoring-template"
  template_description     = "Ubuntu 22.04 with Grafana, Telegraf, and InfluxDB"

  ssh_username             = "root"
  # ssh_password             = "packer"
  ssh_private_key_file = "~/.ssh/id_rsa"
  # Raise the timeout, when installation takes longer
    ssh_timeout = "20m"

  http_directory           = "http"
  boot_command             = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
}

build {
  name = "proxmox-monitoring"
  sources = ["source.proxmox-iso.ubuntu-monitoring"]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/pve.cfg"
        destination = "/tmp/pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/pve.cfg /etc/cloud/cloud.cfg.d/pve.cfg" ]
    }

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      
      # Install Grafana
      "apt-get install -y software-properties-common",
      "wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key",
      "echo 'deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main' | tee -a /etc/apt/sources.list.d/grafana.list",
      "apt-get update",
      "apt-get install -y grafana",
      "systemctl enable grafana-server",
      
      # Install InfluxDB
      "wget -q https://influxdata.com/downloads/influxdb-archive_compat.key",
      "echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdb-archive_compat.key' | sha256sum -c && cat influxdb-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdb-archive_compat.gpg > /dev/null",
      "echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdb-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdb.list",
      "apt-get update",
      "apt-get install -y influxdb",
      "systemctl enable influxdb",
      
      # Install Telegraf
      "apt-get install -y telegraf",
      "systemctl enable telegraf",
      
      # Clean up
      "apt-get clean",
     
    ]
  }
}

# Clean up
# "apt-get clean",
# "rm -rf /var/lib/apt/lists/*"