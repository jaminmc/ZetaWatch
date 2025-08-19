#!/bin/bash

# OpenZFS Installation Script for GitHub Actions
# Installs OpenZFS using Homebrew cask

set -e

# Configuration
INSTALL_PREFIX="/usr/local/zfs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to detect architecture
detect_arch() {
    local arch=$(uname -m)
    echo "$arch"
}

# Function to install OpenZFS via Homebrew
install_openzfs_homebrew() {
    log_info "Installing OpenZFS via Homebrew..."
    
    # Update Homebrew
    brew update
    
    # Install OpenZFS cask
    log_info "Installing OpenZFS cask..."
    brew install --cask openzfs
    
    log_success "OpenZFS cask installed successfully"
}

# Function to verify OpenZFS installation
verify_installation() {
    log_info "Verifying OpenZFS installation..."
    
    # Common locations for OpenZFS libraries
    local possible_locations=(
        "/usr/local/zfs/lib"
        "/usr/local/lib"
        "/opt/homebrew/lib"
    )
    
    local zfs_lib_dir=""
    
    # Find where ZFS libraries are installed
    for dir in "${possible_locations[@]}"; do
        if [ -f "$dir/libzfs.dylib" ] || [ -f "$dir/libzfs.6.dylib" ]; then
            zfs_lib_dir="$dir"
            break
        fi
    done
    
    if [ -z "$zfs_lib_dir" ]; then
        log_error "Could not find ZFS libraries after installation"
        log_info "Searching for ZFS libraries..."
        find /usr/local /opt/homebrew -name "libzfs*.dylib" 2>/dev/null || true
        return 1
    fi
    
    log_success "Found ZFS libraries in: $zfs_lib_dir"
    
    # Show installed libraries
    log_info "Available ZFS libraries:"
    ls -la "$zfs_lib_dir"/lib*zfs*.dylib "$zfs_lib_dir"/lib*nvpair*.dylib 2>/dev/null || true
    
    # Check architecture
    local test_lib="$zfs_lib_dir/libzfs.dylib"
    if [ ! -f "$test_lib" ]; then
        test_lib="$zfs_lib_dir/libzfs.6.dylib"
    fi
    
    if [ -f "$test_lib" ]; then
        log_info "Library architecture:"
        file "$test_lib"
        echo ""
    fi
    
    return 0
}

# Function to create symbolic links for expected library versions
create_library_links() {
    log_info "Creating library version links if needed..."
    
    # Find ZFS library directory
    local zfs_lib_dir=""
    local possible_locations=(
        "/usr/local/zfs/lib"
        "/usr/local/lib"
        "/opt/homebrew/lib"
    )
    
    for dir in "${possible_locations[@]}"; do
        if [ -f "$dir/libzfs.dylib" ] || [ -f "$dir/libzfs.6.dylib" ]; then
            zfs_lib_dir="$dir"
            break
        fi
    done
    
    if [ -z "$zfs_lib_dir" ]; then
        log_warning "Could not find ZFS library directory for link creation"
        return 0
    fi
    
    cd "$zfs_lib_dir"
    
    # Create links for the versions expected by ZetaWatch (if they don't exist)
    if [ -f "libzfs.dylib" ] && [ ! -f "libzfs.6.dylib" ]; then
        ln -sf libzfs.dylib libzfs.6.dylib 2>/dev/null || true
    fi
    if [ -f "libzpool.dylib" ] && [ ! -f "libzpool.6.dylib" ]; then
        ln -sf libzpool.dylib libzpool.6.dylib 2>/dev/null || true
    fi
    if [ -f "libzfs_core.dylib" ] && [ ! -f "libzfs_core.3.dylib" ]; then
        ln -sf libzfs_core.dylib libzfs_core.3.dylib 2>/dev/null || true
    fi
    if [ -f "libnvpair.dylib" ] && [ ! -f "libnvpair.3.dylib" ]; then
        ln -sf libnvpair.dylib libnvpair.3.dylib 2>/dev/null || true
    fi
    
    log_success "Library links checked/created"
}

# Main installation function
main() {
    local target_arch="${1:-$(detect_arch)}"
    
    log_info "Installing OpenZFS via Homebrew for ${target_arch}"
    echo ""
    
    # Check if Homebrew is available
    if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi
    
    # Install OpenZFS via Homebrew
    install_openzfs_homebrew
    
    # Verify installation
    verify_installation
    
    # Create library links if needed
    create_library_links
    
    echo ""
    log_success "OpenZFS installation completed via Homebrew!"
    log_info "Use 'brew list --cask openzfs' to see installation details"
}

# Show usage if help requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [architecture]"
    echo ""
    echo "Install OpenZFS via Homebrew cask"
    echo ""
    echo "Arguments:"
    echo "  architecture    Target architecture (for logging purposes only)"
    echo ""
    echo "Examples:"
    echo "  $0              # Install OpenZFS via Homebrew"
    echo "  $0 x86_64       # Install for Intel (same as above)"
    echo "  $0 arm64        # Install for Apple Silicon (same as above)"
    echo ""
    echo "Note: Homebrew automatically installs the correct architecture"
    exit 0
fi

# Run main function
main "$@"
