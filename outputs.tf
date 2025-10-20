
output "created_nfs_storages" {
  description = "Set of created NFS storage names"
  value       = keys(module.nfs_storage)
}

output "created_backup_jobs" {
  description = "List of created backup job IDs"
  value       = keys(module.backup_job)
}

output "nfs_storage_details" {
  description = "Details of created NFS storages"
  value = {
    for k, v in module.nfs_storage : k => {
      storage_name = v.storage_name
    }
  }
}

output "backup_job_details" {
  description = "Details of created backup jobs"
  value = {
    for k, v in module.backup_job : k => {
      job_id = v.job_id
    }
  }
}
