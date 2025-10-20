variable "id" {
  description = "Unique identifier for the backup job"
  type        = string
}

variable "vms" {
  description = "List of VM IDs to backup"
  type        = list(string)
}

variable "storage" {
  description = "Storage name to backup to"
  type        = string
}

variable "schedule" {
  description = "Cron schedule for the backup job"
  type        = string
}

variable "mode" {
  description = "Backup mode: snapshot, stop, or suspend"
  type        = string

  validation {
    condition     = contains(["snapshot", "stop", "suspend"], var.mode)
    error_message = "Mode must be one of: snapshot, stop, suspend."
  }
}

variable "maxfiles" {
  description = "Maximum number of backup files to keep"
  type        = number
}
