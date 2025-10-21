#!/bin/bash

# Proxmox VE Infrastructure Automation - Installation Script
# Senior Systems Administrator - Infrastructure Team
# This script installs Terraform if needed and sets up the Proxmox backup infrastructure

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

error_exit() {
    error "$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Detect OS and architecture
detect_system() {
    log "Detecting system architecture..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="darwin"
    else
        error_exit "Unsupported operating system: $OSTYPE"
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) error_exit "Unsupported architecture: $ARCH" ;;
    esac
    
    success "Detected: $OS-$ARCH"
}

# Check if Terraform is installed
check_terraform() {
    log "Checking Terraform installation..."
    
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2 | cut -d'v' -f2)
        log "Terraform found: version $TERRAFORM_VERSION"
        
        # Check if version is >= 1.6
        REQUIRED_VERSION="1.6.0"
        if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
            success "Terraform version $TERRAFORM_VERSION meets requirements (>= 1.6.0)"
            return 0
        else
            warning "Terraform version $TERRAFORM_VERSION is too old. Required: >= 1.6.0"
            return 1
        fi
    else
        log "Terraform not found"
        return 1
    fi
}

# Install Terraform
install_terraform() {
    log "Installing Terraform..."
    
    # Get latest version
    TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r '.tag_name' | sed 's/v//')
    
    if [ -z "$TERRAFORM_VERSION" ] || [ "$TERRAFORM_VERSION" = "null" ]; then
        error_exit "Failed to get Terraform version from GitHub API"
    fi
    
    log "Installing Terraform version $TERRAFORM_VERSION..."
    
    # Download and install
    DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"
    
    cd /tmp
    curl -LO "$DOWNLOAD_URL" || error_exit "Failed to download Terraform"
    
    unzip -o "terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" || error_exit "Failed to extract Terraform"
    
    mv terraform /usr/local/bin/ || error_exit "Failed to move Terraform to /usr/local/bin"
    chmod +x /usr/local/bin/terraform
    
    # Cleanup
    rm -f "terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"
    
    success "Terraform $TERRAFORM_VERSION installed successfully"
}

# Install required dependencies
install_dependencies() {
    log "Installing required dependencies..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y curl unzip jq openssh-client
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum update -y
        yum install -y curl unzip jq openssh-clients
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf update -y
        dnf install -y curl unzip jq openssh-clients
    elif command -v brew &> /dev/null; then
        # macOS
        brew install curl unzip jq openssh
    else
        warning "Package manager not detected. Please install: curl, unzip, jq, openssh-client"
    fi
    
    success "Dependencies installed"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform installation failed"
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2 | cut -d'v' -f2)
    success "Terraform $TERRAFORM_VERSION is ready"
    
    # Check other dependencies
    for cmd in curl unzip jq ssh; do
        if ! command -v $cmd &> /dev/null; then
            warning "$cmd not found - please install manually if needed"
        else
            success "$cmd is available"
        fi
    done
}

# Make setup script executable and run it
run_setup() {
    log "Preparing setup script..."
    
    # Make setup.sh executable
    chmod +x setup.sh
    
    # Check if setup.sh exists
    if [ ! -f "setup.sh" ]; then
        error_exit "setup.sh not found in current directory"
    fi
    
    success "Setup script is ready"
    
    log "Starting interactive setup..."
    echo ""
    echo "=========================================="
    echo "  Proxmox VE Infrastructure Setup"
    echo "=========================================="
    echo ""
    
    # Run the setup script
    ./setup.sh
}

# Main installation process
main() {
    echo ""
    echo "=========================================="
    echo "  Proxmox VE Infrastructure Installation"
    echo "=========================================="
    echo ""
    
    check_root
    detect_system
    install_dependencies
    
    if ! check_terraform; then
        install_terraform
    fi
    
    verify_installation
    run_setup
    
    echo ""
    success "Installation and setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Review the created infrastructure in Proxmox VE"
    echo "2. Check backup job schedules in the Proxmox web interface"
    echo "3. Monitor backup execution logs"
    echo ""
}

# Run main function
main "$@"
