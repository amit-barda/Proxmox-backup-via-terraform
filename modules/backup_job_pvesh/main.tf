# Fallback module using pvesh CLI when proxmox_backup_job is not supported
# This module uses null_resource with local-exec to call pvesh commands

resource "null_resource" "backup_job" {
  triggers = {
    id       = var.id
    storage  = var.storage
    vms      = join(",", var.vms)
    schedule = var.schedule
    mode     = var.mode
    maxfiles = var.maxfiles
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create backup job using pvesh
      pvesh create /cluster/backup \
        --id "${var.id}" \
        --storage "${var.storage}" \
        --vms "${join(",", var.vms)}" \
        --schedule "${var.schedule}" \
        --mode "${var.mode}" \
        --maxfiles "${var.maxfiles}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete backup job using pvesh
      pvesh delete /cluster/backup/${var.id} || true
    EOT
  }
}
