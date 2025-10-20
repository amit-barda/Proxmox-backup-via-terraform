variable "storage_name" {
  description = "Name of the NFS storage"
  type        = string
}

variable "server" {
  description = "NFS server IP or hostname"
  type        = string
}

variable "export" {
  description = "NFS export path"
  type        = string
}

variable "content" {
  description = "Content types allowed on this storage"
  type        = list(string)
}

variable "nodes" {
  description = "List of Proxmox nodes to mount this storage on"
  type        = list(string)
}

variable "maxfiles" {
  description = "Maximum number of backup files to keep"
  type        = number
  default     = null
}

variable "enabled" {
  description = "Whether the storage is enabled"
  type        = bool
  default     = true
}
