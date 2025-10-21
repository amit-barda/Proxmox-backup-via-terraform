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
    pm_ssh_host  = var.pm_ssh_host
    pm_ssh_user  = var.pm_ssh_user
    pm_ssh_key   = var.pm_ssh_private_key_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Parse cron schedule and create backup job
      CRON_SCHEDULE="${self.triggers.schedule}"
      
      # Extract time from cron (format: minute hour * * *)
      HOUR=$(echo $CRON_SCHEDULE | awk '{print $2}')
      MINUTE=$(echo $CRON_SCHEDULE | awk '{print $1}')
      
      # Convert to HH:MM format
      STARTTIME=$(printf "%02d:%02d" $HOUR $MINUTE)
      
      # For now, set daily backup (can be enhanced to parse day of week)
      DOW="mon,tue,wed,thu,fri,sat,sun"
      
      # Create backup job via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh create /cluster/backup ${self.triggers.id} --all 0 --vmid '${self.triggers.vms}' --storage '${self.triggers.storage}' --mode '${self.triggers.mode}' --maxfiles '${self.triggers.maxfiles}' --enabled 1 --starttime '$STARTTIME' --dow '$DOW'"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete backup job via SSH + pvesh
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh delete /cluster/backup/${self.triggers.id}" || true
    EOT
  }
}
