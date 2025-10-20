# Backup Job management using pvesh CLI
# Since proxmox_backup_job resource doesn't exist in Telmate/proxmox provider
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
      pvesh delete /cluster/backup/${self.triggers.id} || true
    EOT
  }
}
