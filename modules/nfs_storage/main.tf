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
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create NFS storage on Proxmox via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${var.pm_ssh_private_key_path}" "${var.pm_ssh_user}@${var.pm_ssh_host}" \
        "pvesh create /storage --storage '${var.storage_name}' --type nfs --server '${var.server}' --export '${var.export}' --content '${join(",", var.content)}' --nodes '${join(",", var.nodes)}' ${var.maxfiles != null ? format("--maxfiles %d", var.maxfiles) : ""} ${!var.enabled ? "--disable" : ""}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete NFS storage via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${var.pm_ssh_private_key_path}" "${var.pm_ssh_user}@${var.pm_ssh_host}" \
        "pvesh delete /storage/${self.triggers.storage_name}" || true
    EOT
  }
}
