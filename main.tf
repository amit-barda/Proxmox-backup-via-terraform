# NFS Storage modules
module "nfs_storage" {
  for_each = var.nfs_storages

  source = "./modules/nfs_storage"

  storage_name = each.key
  server       = each.value.server
  export       = each.value.export
  content      = each.value.content
  nodes        = each.value.nodes
  maxfiles     = each.value.maxfiles
  enabled      = each.value.enabled

  pm_ssh_host             = var.pm_ssh_host
  pm_ssh_user             = var.pm_ssh_user
  pm_ssh_private_key_path = var.pm_ssh_private_key_path
}

# Backup Job modules
module "backup_job" {
  for_each = var.backup_jobs

  source = "./modules/backup_job"

  id       = each.key
  vms      = each.value.vms
  storage  = each.value.storage
  schedule = each.value.schedule
  mode     = each.value.mode
  maxfiles = each.value.maxfiles

  pm_ssh_host             = var.pm_ssh_host
  pm_ssh_user             = var.pm_ssh_user
  pm_ssh_private_key_path = var.pm_ssh_private_key_path

  depends_on = [module.nfs_storage]
}
