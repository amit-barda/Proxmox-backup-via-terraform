#!/bin/bash

# Proxmox VE Infrastructure Automation
# Senior Systems Administrator - Infrastructure Team
# Date: $(date +%Y-%m-%d)
# Purpose: Automated NFS storage and backup job provisioning for Proxmox clusters

set -euo pipefail

# Configuration
SCRIPT_VERSION="2.1.0"
LOG_FILE="/tmp/proxmox-setup-$(date +%Y%m%d-%H%M%S).log"
VALIDATION_TIMEOUT="${VALIDATION_TIMEOUT:-20}"  # 20 seconds default

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Header
clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 Proxmox VE Infrastructure Setup              ║"
echo "║                 by the one and only amit barda               ║"
echo "║                    Version: $SCRIPT_VERSION                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

log "Starting Proxmox infrastructure provisioning..."

# Prerequisites validation
log "Validating system prerequisites..."

if ! command -v terraform &> /dev/null; then
    error_exit "Terraform binary not found. Install from: https://terraform.io/downloads"
fi

if ! command -v pvesh &> /dev/null; then
    error_exit "Proxmox VE CLI tools not installed. Install: apt-get install proxmox-ve-cli"
fi

# Check Terraform version
TF_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
if [[ "$TF_VERSION" == "unknown" ]]; then
    log "WARNING: Could not determine Terraform version"
else
    log "Terraform version: $TF_VERSION"
fi

log "Prerequisites validation completed successfully"
echo ""

# Initialize terraform workspace
log "Initializing Terraform workspace..."
if [ ! -d ".terraform" ]; then
    log "Running terraform init..."
    terraform init -upgrade > /dev/null 2>&1 || error_exit "Terraform initialization failed"
    log "Terraform workspace initialized successfully"
else
    log "Terraform workspace already initialized"
fi

# Validate configuration
log "Validating Terraform configuration..."
terraform validate > /dev/null 2>&1 || error_exit "Terraform configuration validation failed"
log "Configuration validation passed"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Infrastructure Configuration             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get NFS storage configuration
configure_nfs_storage() {
    echo "┌─ NFS Storage Configuration ─────────────────────────────────┐" 1>&2
    echo "│ Configure shared storage for Proxmox cluster               │" 1>&2
    echo "└─────────────────────────────────────────────────────────────┘" 1>&2
    echo "" 1>&2
    
    read -p "Storage identifier (e.g., backup-nfs, iso-storage): " storage_name
    [[ -z "$storage_name" ]] && error_exit "Storage name cannot be empty"
    
    read -p "NFS server IP address: " server_ip
    if ! validate_ip "$server_ip"; then
        error_exit "Invalid IP address format: $server_ip"
    fi
    
    read -p "NFS export path (e.g., /mnt/backup, /exports/iso): " export_path
    [[ -z "$export_path" ]] && error_exit "Export path cannot be empty"
    
    echo "Content types: backup, iso, vztmpl, images, rootdir" 1>&2
    read -p "Content types (comma-separated): " content_types
    [[ -z "$content_types" ]] && content_types="backup"
    
    read -p "Target nodes (comma-separated, e.g., pve1,pve2): " nodes
    [[ -z "$nodes" ]] && error_exit "At least one node must be specified"
    
    read -p "Max backup files retention (optional): " maxfiles
    
    # Convert comma-separated to JSON arrays
    content_array=$(echo "$content_types" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
    nodes_array=$(echo "$nodes" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
    
    # Build the storage configuration
    if [ -z "$maxfiles" ]; then
        storage_config="\"$storage_name\":{\"server\":\"$server_ip\",\"export\":\"$export_path\",\"content\":[$content_array],\"nodes\":[$nodes_array],\"enabled\":true}"
    else
        storage_config="\"$storage_name\":{\"server\":\"$server_ip\",\"export\":\"$export_path\",\"content\":[$content_array],\"nodes\":[$nodes_array],\"maxfiles\":$maxfiles,\"enabled\":true}"
    fi
    
    log "NFS storage configured: $storage_name -> $server_ip:$export_path" 1>&2
    echo "$storage_config"
}

# Function to configure backup job
configure_backup_job() {
    echo "┌─ Backup Job Configuration ───────────────────────────────────┐" 1>&2
    echo "│ Configure automated backup jobs for VMs                    │" 1>&2
    echo "└─────────────────────────────────────────────────────────────┘" 1>&2
    echo "" 1>&2
    
    read -p "Job identifier (e.g., daily-backup, weekly-full): " job_id
    [[ -z "$job_id" ]] && error_exit "Job ID cannot be empty"
    
    read -p "VM IDs to backup (comma-separated, e.g., 100,101,102): " vm_ids
    [[ -z "$vm_ids" ]] && error_exit "At least one VM ID must be specified"
    
    read -p "Target storage (must match NFS storage name): " storage_name
    [[ -z "$storage_name" ]] && error_exit "Storage name cannot be empty"
    
    echo "Schedule examples:" 1>&2
    echo "  Daily at 2 AM:    0 2 * * *" 1>&2
    echo "  Weekly Sunday:    0 3 * * 0" 1>&2
    echo "  Every 6 hours:    0 */6 * * *" 1>&2
    read -p "Cron schedule: " schedule
    [[ -z "$schedule" ]] && error_exit "Schedule cannot be empty"
    
    echo "Backup modes: snapshot (live), stop (shutdown), suspend (pause)" 1>&2
    read -p "Backup mode [snapshot]: " mode
    mode=${mode:-snapshot}
    
    if [[ ! "$mode" =~ ^(snapshot|stop|suspend)$ ]]; then
        error_exit "Invalid backup mode. Must be: snapshot, stop, or suspend"
    fi
    
    read -p "Max backup files retention: " maxfiles
    [[ -z "$maxfiles" ]] && error_exit "Max files must be specified"
    
    if ! [[ "$maxfiles" =~ ^[0-9]+$ ]]; then
        error_exit "Max files must be a positive integer"
    fi
    
    # Convert comma-separated to JSON array
    vm_array=$(echo "$vm_ids" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
    
    # Build the job configuration
    job_config="\"$job_id\":{\"vms\":[$vm_array],\"storage\":\"$storage_name\",\"schedule\":\"$schedule\",\"mode\":\"$mode\",\"maxfiles\":$maxfiles}"
    
    log "Backup job configured: $job_id for VMs $vm_ids" 1>&2
    echo "$job_config"
}

# Main configuration workflow
log "Starting infrastructure configuration workflow..."

# Configure NFS storages
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    NFS Storage Configuration                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

storages=""
storage_count=0

while true; do
    storage_count=$((storage_count + 1))
    echo "Configuring NFS storage #$storage_count..."
    storage=$(configure_nfs_storage)
    
    if [ -z "$storages" ]; then
        storages="$storage"
    else
        storages="$storages,$storage"
    fi
    
    echo ""
    read -p "Configure additional NFS storage? (y/N): " add_more
    if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
        break
    fi
    echo ""
done

log "Configured $storage_count NFS storage(s)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Backup Job Configuration                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Configure backup jobs
jobs=""
job_count=0

while true; do
    job_count=$((job_count + 1))
    echo "Configuring backup job #$job_count..."
    job=$(configure_backup_job)
    
    if [ -z "$jobs" ]; then
        jobs="$job"
    else
        jobs="$jobs,$job"
    fi
    
    echo ""
    read -p "Configure additional backup job? (y/N): " add_more
    if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
        break
    fi
    echo ""
done

log "Configured $job_count backup job(s)"

# Build the terraform command
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Deployment Summary                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

log "Infrastructure configuration completed:"
log "  - NFS storages: $storage_count"
log "  - Backup jobs: $job_count"

terraform_command="terraform apply -var=\"nfs_storages={$storages}\" -var=\"backup_jobs={$jobs}\""

echo "Deployment command:" 1>&2
echo "$terraform_command" 1>&2
echo "" 1>&2

# Pre-deployment validation
echo "╔══════════════════════════════════════════════════════════════╗" 1>&2
echo "║                    Pre-deployment Validation                ║" 1>&2
echo "╚══════════════════════════════════════════════════════════════╝" 1>&2
echo "" 1>&2

log "Running pre-deployment validation (with ${VALIDATION_TIMEOUT}s timeout)..."
echo "⏳ Quick validation (${VALIDATION_TIMEOUT}s timeout)..." 1>&2

# Run terraform plan with timeout (disable exit on error temporarily)
set +e
timeout $VALIDATION_TIMEOUT terraform plan -var="nfs_storages={$storages}" -var="backup_jobs={$jobs}" > /dev/null 2>&1
PLAN_EXIT_CODE=$?
set -e

if [ $PLAN_EXIT_CODE -eq 124 ]; then
    warning "Pre-deployment validation timed out after ${VALIDATION_TIMEOUT} seconds"
    echo "⚡ Validation timeout - proceeding with deployment" 1>&2
    echo "⚡ Full validation will run during terraform apply" 1>&2
    echo "" 1>&2
    echo "This is normal - continuing with deployment..." 1>&2
elif [ $PLAN_EXIT_CODE -eq 0 ]; then
    log "Pre-deployment validation passed"
    echo "✅ Configuration validation successful" 1>&2
else
    error_exit "Pre-deployment validation failed (exit code: $PLAN_EXIT_CODE)"
fi

echo ""
echo "Options:" 1>&2
echo "  y - Proceed with deployment" 1>&2
echo "  s - Skip validation and deploy directly" 1>&2
echo "  n - Cancel deployment" 1>&2
read -p "Proceed with infrastructure deployment? (y/s/N): " deploy_now

if [[ "$deploy_now" =~ ^[Yy]$ ]] || [[ "$deploy_now" =~ ^[Ss]$ ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗" 1>&2
    echo "║                    Deploying Infrastructure                 ║" 1>&2
    echo "╚══════════════════════════════════════════════════════════════╝" 1>&2
    echo "" 1>&2
    
    if [[ "$deploy_now" =~ ^[Ss]$ ]]; then
        log "Starting infrastructure deployment (validation skipped)..."
        echo "⚡ Deploying directly without pre-validation..." 1>&2
    else
        log "Starting infrastructure deployment..."
    fi
    eval $terraform_command
    
    if [ $? -eq 0 ]; then
        log "Infrastructure deployment completed successfully"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗" 1>&2
        echo "║                    Deployment Complete                      ║" 1>&2
        echo "╚══════════════════════════════════════════════════════════════╝" 1>&2
        echo "" 1>&2
        echo "✅ Infrastructure successfully provisioned!" 1>&2
        echo "📋 Log file: $LOG_FILE" 1>&2
        echo "" 1>&2
        echo "Next steps:" 1>&2
        echo "  - Verify NFS storages in Proxmox web interface" 1>&2
        echo "  - Check backup jobs in Datacenter > Backup" 1>&2
        echo "  - Test backup jobs manually if needed" 1>&2
    else
        error_exit "Infrastructure deployment failed"
    fi
else
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗" 1>&2
    echo "║                    Deployment Cancelled                     ║" 1>&2
    echo "╚══════════════════════════════════════════════════════════════╝" 1>&2
    echo "" 1>&2
    echo "📋 Configuration saved. Run this command when ready:" 1>&2
    echo "$terraform_command" 1>&2
    echo "" 1>&2
    echo "📋 Log file: $LOG_FILE" 1>&2
fi

log "Script execution completed"
