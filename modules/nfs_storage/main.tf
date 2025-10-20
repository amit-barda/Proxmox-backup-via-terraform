# NFS Storage management using pvesh CLI
# Since proxmox_storage resource doesn't exist in Telmate/proxmox provider
resource "null_resource" "nfs_storage" {
  triggers = {
    storage_name = var.storage_name
    server       = var.server
    export       = var.export
    content      = join(",", var.content)
    nodes        = join(",", var.nodes)
    maxfiles     = var.maxfiles
    enabled      = var.enabled
    pm_ssh_host  = var.pm_ssh_host
    pm_ssh_user  = var.pm_ssh_user
    pm_ssh_key   = var.pm_ssh_private_key_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create NFS storage on Proxmox via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh create /storage --storage '${self.triggers.storage_name}' --type nfs --server '${self.triggers.server}' --export '${self.triggers.export}' --content '${self.triggers.content}' --nodes '${self.triggers.nodes}' ${self.triggers.enabled == "false" ? "--disable" : ""}"
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure maxfiles if specified
      if [ "${self.triggers.maxfiles}" != "" ] && [ "${self.triggers.maxfiles}" != "null" ]; then
        ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
          "pvesh set /storage/${self.triggers.storage_name} --maxfiles ${self.triggers.maxfiles}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete NFS storage via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh delete /storage/${self.triggers.storage_name}" || true
    EOT
  }
}
