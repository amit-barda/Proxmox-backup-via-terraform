output "storage_name" {
  description = "Name of the created NFS storage"
  value       = null_resource.nfs_storage.triggers.storage_name
}
