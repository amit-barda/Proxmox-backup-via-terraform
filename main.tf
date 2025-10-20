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

  depends_on = [module.nfs_storage]
}
