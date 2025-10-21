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
      
      # Parse day of week from cron (5th field)
      DOW_FIELD=$(echo $CRON_SCHEDULE | awk '{print $5}')
      
      # Convert cron DOW to Proxmox format
      case "$DOW_FIELD" in
        "*") DOW="mon,tue,wed,thu,fri,sat,sun" ;;
        "0") DOW="sun" ;;
        "1") DOW="mon" ;;
        "2") DOW="tue" ;;
        "3") DOW="wed" ;;
        "4") DOW="thu" ;;
        "5") DOW="fri" ;;
        "6") DOW="sat" ;;
        "0,1,2,3,4,5,6") DOW="mon,tue,wed,thu,fri,sat,sun" ;;
        "1,2,3,4,5") DOW="mon,tue,wed,thu,fri" ;;
        *) DOW="mon,tue,wed,thu,fri,sat,sun" ;; # Default to daily
      esac
      
      # Create backup job using correct pvesh syntax
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh create /cluster/backup --id '${self.triggers.id}' --all 0 --vmid '${self.triggers.vms}' --storage '${self.triggers.storage}' --mode '${self.triggers.mode}' --starttime '$STARTTIME' --dow '$DOW' --enabled 1"
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Set maxfiles after job creation
      ssh -o StrictHostKeyChecking=no -i "${self.triggers.pm_ssh_key}" "${self.triggers.pm_ssh_user}@${self.triggers.pm_ssh_host}" \
        "pvesh set /cluster/backup/${self.triggers.id} --maxfiles ${self.triggers.maxfiles}"
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
