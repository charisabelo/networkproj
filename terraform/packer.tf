resource "null_resource" "packer_build" {
  provisioner "local-exec" {
    command = "packer build ../packer/proxmox-monitoring-template.pkr.hcl"
    working_dir = path.module
  }
}