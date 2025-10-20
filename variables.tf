# Proxmox connection variables
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "pm_user" {
  description = "Proxmox username"
  type        = string
}

variable "pm_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = false
}

# SSH to Proxmox node for pvesh execution
variable "pm_ssh_host" {
  description = "Proxmox node hostname/IP for SSH (to run pvesh)"
  type        = string
}

variable "pm_ssh_user" {
  description = "SSH user to connect to Proxmox node"
  type        = string
  default     = "root"
}

variable "pm_ssh_private_key_path" {
  description = "Path to SSH private key for Proxmox node"
  type        = string
}

# NFS Storage configuration - Interactive input
variable "nfs_storages" {
  description = "Map of NFS storage configurations"
  type = map(object({
    server   = string
    export   = string
    content  = list(string)
    nodes    = list(string)
    maxfiles = optional(number)
    enabled  = optional(bool, true)
  }))
  default = {}
}

# Backup Job configuration - Interactive input
variable "backup_jobs" {
  description = "Map of backup job configurations"
  type = map(object({
    vms      = list(string)
    storage  = string
    schedule = string
    mode     = string
    maxfiles = number
  }))
  default = {}

  validation {
    condition = alltrue([
      for job in var.backup_jobs : contains(["snapshot", "stop", "suspend"], job.mode)
    ])
    error_message = "Backup job mode must be one of: snapshot, stop, suspend."
  }

  validation {
    condition = alltrue([
      for job in var.backup_jobs : length(trimspace(job.schedule)) > 0
    ])
    error_message = "Backup job schedule cannot be empty. Example: 0 2 * * *."
  }
}
