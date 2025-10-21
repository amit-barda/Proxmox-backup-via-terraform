# Proxmox VE Infrastructure Automation

**Senior Systems Administrator - Infrastructure Team**

This Terraform-based infrastructure automation solution provides enterprise-grade management of Proxmox VE NFS storages and backup jobs. Designed for production environments with emphasis on reliability, maintainability, and operational excellence.

## Enterprise Deployment Guide

### Prerequisites
- **Terraform** >= 1.6 (auto-installed by install.sh)
- **Proxmox VE CLI** (`pvesh` command)
- **Network connectivity** to Proxmox cluster
- **Administrative privileges** on Proxmox nodes
- **Supported OS**: Linux (Debian/Ubuntu, RHEL/CentOS, Fedora), macOS

### Quick Deployment

1. **One-Command Installation:**
   ```bash
   # Clone and run automated installation
   git clone https://github.com/amit-barda/Proxmox-backup-via-terraform.git
   cd Proxmox-backup-via-terraform
   sudo ./install.sh
   ```
   
   The installation script will:
   - **Auto-install Terraform** (if not present or version < 1.6)
   - **Install dependencies** (curl, unzip, jq, openssh)
   - **Detect system architecture** (Linux/macOS, amd64/arm64)
   - **Run interactive setup** automatically

2. **Manual Installation (Alternative):**
   ```bash
   # Clone and navigate to project directory
   cd proxmox-backup
   
   # Make setup script executable
   chmod +x setup.sh
   
   # Configure Proxmox Authentication
   # Edit terraform.tfvars with your cluster details
   ```

3. **Configure Proxmox Authentication:**
   Edit `terraform.tfvars` with your cluster details:
   ```hcl
   pm_api_url      = "https://your-proxmox-cluster:8006/api2/json"
   pm_user         = "root@pam"
   pm_password     = "your_secure_password"
   pm_tls_insecure = false  # Set to true only for development
   ```

4. **Interactive Infrastructure Provisioning:**
   ```bash
   ./setup.sh
   ```
   
   The enterprise setup script provides:
   - **Input validation** for all parameters
   - **Quick pre-deployment validation** with Terraform plan (20s timeout)
   - **Skip validation option** for faster deployment
   - **Comprehensive logging** to `/tmp/proxmox-setup-*.log`
   - **Error handling** with graceful failure modes
   - **Professional UI** with structured output

5. **Manual Deployment (Advanced):**
   ```bash
   terraform init
   terraform validate
   terraform plan -var="nfs_storages={...}" -var="backup_jobs={...}"
   terraform apply -var="nfs_storages={...}" -var="backup_jobs={...}"
   ```

6. **Custom Validation Timeout:**
   ```bash
   # Set custom timeout (in seconds) for validation
   VALIDATION_TIMEOUT=60 ./setup.sh  # 1 minute
   ```

## Project Structure

```
proxmox-backup/
├─ modules/
│  ├─ nfs_storage/          # NFS storage management
│  ├─ backup_job/           # Backup job management (preferred)
│  └─ backup_job_pvesh/     # Fallback using pvesh CLI
├─ main.tf                  # Root module configuration
├─ variables.tf             # Input variables
├─ outputs.tf               # Output values
├─ terraform.tfvars         # Environment configuration
└─ README.md                # This file
```

## Configuration Examples

### NFS Storage Configuration
```hcl
nfs_storages = {
  "backup-nfs" = {
    server   = "192.168.1.200"
    export   = "/mnt/backup"
    content  = ["backup", "iso"]
    nodes    = ["pve1", "pve2"]
    maxfiles = 2
    enabled  = true
  }
}
```

### Backup Job Configuration
```hcl
backup_jobs = {
  "daily-backup" = {
    vms      = ["100", "101", "102"]
    storage  = "backup-nfs"
    schedule = "0 2 * * *"  # Daily at 2 AM
    mode     = "snapshot"   # snapshot, stop, or suspend
    maxfiles = 7
  }
}
```

## Schedule Format Examples

- `"0 2 * * *"` - Daily at 2 AM
- `"0 3 * * 0"` - Weekly on Sunday at 3 AM
- `"0 1 1 * *"` - Monthly on the 1st at 1 AM
- `"0 */6 * * *"` - Every 6 hours

## Important Notes

### Implementation Details
This project uses `pvesh` CLI commands via `null_resource` provisioners because:
- `proxmox_storage` resource doesn't exist in Telmate/proxmox provider
- `proxmox_backup_job` resource doesn't exist in Telmate/proxmox provider

### Prerequisites
- `pvesh` CLI tool must be installed and configured
- Proper authentication to Proxmox API
- Node names in `nodes` list must exactly match your Proxmox node names
- VM IDs must be valid and exist in your Proxmox cluster

### Node Names
- Check node names with: `pvesh get /nodes`

### VM IDs
- Check VM IDs with: `pvesh get /cluster/resources --type vm`

### Authentication
For production, consider using API tokens instead of passwords:
```hcl
pm_user     = "user@pam!token_name"
pm_password = "your_token_here"
```

### Alternative Modules
The `backup_job_pvesh` module provides the same functionality as `backup_job` - both use `pvesh` CLI.

## Troubleshooting

### Common Issues
1. **Node names don't match**: Verify with `pvesh get /nodes`
2. **VM IDs invalid**: Check with `pvesh get /cluster/resources --type vm`
3. **Storage already exists**: Remove manually or use different names
4. **Schedule format**: Proxmox validates cron syntax - check logs for errors

### Validation Commands
```bash
terraform validate
terraform plan -detailed-exitcode
```

## Next Steps After Changes

1. `terraform init` - Initialize providers
2. `terraform validate` - Check syntax
3. `terraform plan` - Review changes
4. `terraform apply` - Apply configuration
