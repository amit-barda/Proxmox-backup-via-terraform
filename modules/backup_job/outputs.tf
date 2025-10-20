output "job_id" {
  description = "ID of the created backup job"
  value       = null_resource.backup_job.triggers.id
}
