#!/bin/bash

# OpenZFS Installation Script for GitHub Actions
# Downloads and builds OpenZFS macOS 2.3.0 for the target architecture

set -e

# Configuration
OPENZFS_VERSION="zfs-macOS-2.3.0"
OPENZFS_URL="https://github.com/openzfsonosx/openzfs-fork/archive/refs/tags/${OPENZFS_VERSION}.tar.gz"
INSTALL_PREFIX="/usr/local/zfs"
BUILD_JOBS="$(sysctl -n hw.logicalcpu)"

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

# Function to install dependencies
install_dependencies() {
    log_info "Installing build dependencies..."
    
    # Install Xcode command line tools if not present
    if ! command -v xcode-select >/dev/null 2>&1; then
        log_info "Installing Xcode command line tools..."
        xcode-select --install
    fi
    
    # Install autotools via Homebrew if available
    if command -v brew >/dev/null 2>&1; then
        log_info "Installing build tools via Homebrew..."
        brew install autoconf automake libtool
    else
        log_warning "Homebrew not available - ensure autotools are installed"
    fi
    
    log_success "Dependencies installed"
}

# Function to download OpenZFS source
download_openzfs() {
    log_info "Downloading OpenZFS ${OPENZFS_VERSION}..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    curl -L -o "openzfs-${OPENZFS_VERSION}.tar.gz" "$OPENZFS_URL"
    tar -xzf "openzfs-${OPENZFS_VERSION}.tar.gz"
    
    # Return the extracted directory path
    echo "$temp_dir/openzfs-fork-${OPENZFS_VERSION}"
}

# Function to configure OpenZFS build
configure_openzfs() {
    local source_dir="$1"
    local target_arch="$2"
    
    log_info "Configuring OpenZFS for ${target_arch}..."
    
    cd "$source_dir"
    
    # Generate configure script
    ./autogen.sh
    
    # Configure for macOS with specific architecture
    local configure_args=(
        "--prefix=${INSTALL_PREFIX}"
        "--with-config=user"
        "--enable-systemd=no"
        "--enable-sysvinit=no"
    )
    
    # Add architecture-specific flags
    if [ "$target_arch" = "x86_64" ]; then
        configure_args+=(
            "CFLAGS=-arch x86_64"
            "CXXFLAGS=-arch x86_64"
            "LDFLAGS=-arch x86_64"
        )
    elif [ "$target_arch" = "arm64" ]; then
        configure_args+=(
            "CFLAGS=-arch arm64"
            "CXXFLAGS=-arch arm64" 
            "LDFLAGS=-arch arm64"
        )
    fi
    
    ./configure "${configure_args[@]}"
    
    log_success "OpenZFS configured for ${target_arch}"
}

# Function to build OpenZFS
build_openzfs() {
    local source_dir="$1"
    local target_arch="$2"
    
    log_info "Building OpenZFS for ${target_arch}..."
    
    cd "$source_dir"
    
    # Build userland tools and libraries
    make -j"$BUILD_JOBS"
    
    log_success "OpenZFS built successfully"
}

# Function to install OpenZFS
install_openzfs() {
    local source_dir="$1"
    local target_arch="$2"
    
    log_info "Installing OpenZFS libraries..."
    
    cd "$source_dir"
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_PREFIX"/{lib,include,bin,sbin}
    
    # Install libraries and headers
    sudo make install
    
    # Verify installation
    if [ -f "${INSTALL_PREFIX}/lib/libzfs.dylib" ]; then
        log_success "OpenZFS installed successfully"
        
        # Show installed libraries
        log_info "Installed libraries:"
        ls -la "${INSTALL_PREFIX}/lib/"*.dylib 2>/dev/null || true
        
        # Show architecture of installed libraries
        for lib in "${INSTALL_PREFIX}/lib/"*.dylib; do
            if [ -f "$lib" ]; then
                echo "  $(basename "$lib"): $(file "$lib" | cut -d: -f2 | xargs)"
            fi
        done
    else
        log_error "OpenZFS installation failed"
        return 1
    fi
}

# Function to create symbolic links for expected library versions
create_library_links() {
    log_info "Creating library version links..."
    
    cd "${INSTALL_PREFIX}/lib"
    
    # Create links for the versions expected by ZetaWatch
    sudo ln -sf libzfs.dylib libzfs.6.dylib 2>/dev/null || true
    sudo ln -sf libzpool.dylib libzpool.6.dylib 2>/dev/null || true
    sudo ln -sf libzfs_core.dylib libzfs_core.3.dylib 2>/dev/null || true
    sudo ln -sf libnvpair.dylib libnvpair.3.dylib 2>/dev/null || true
    
    log_success "Library links created"
}

# Function to cleanup temporary files
cleanup() {
    if [ -n "$1" ] && [ -d "$1" ]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$1"
    fi
}

# Main installation function
main() {
    local target_arch="${1:-$(detect_arch)}"
    
    log_info "Installing OpenZFS ${OPENZFS_VERSION} for ${target_arch}"
    log_info "Installation prefix: ${INSTALL_PREFIX}"
    echo ""
    
    # Trap cleanup on exit
    local temp_dir=""
    trap 'cleanup "$temp_dir"' EXIT
    
    # Install dependencies
    install_dependencies
    
    # Download source
    temp_dir=$(download_openzfs)
    
    # Configure build
    configure_openzfs "$temp_dir" "$target_arch"
    
    # Build OpenZFS
    build_openzfs "$temp_dir" "$target_arch"
    
    # Install OpenZFS
    install_openzfs "$temp_dir" "$target_arch"
    
    # Create library links
    create_library_links
    
    echo ""
    log_success "OpenZFS ${OPENZFS_VERSION} installation completed!"
    log_info "Libraries installed in: ${INSTALL_PREFIX}/lib"
    log_info "Headers installed in: ${INSTALL_PREFIX}/include"
    
    # Show final verification
    if [ -f "${INSTALL_PREFIX}/lib/libzfs.6.dylib" ]; then
        echo ""
        log_info "Verification:"
        file "${INSTALL_PREFIX}/lib/libzfs.6.dylib"
        otool -L "${INSTALL_PREFIX}/lib/libzfs.6.dylib" | head -5
    fi
}

# Show usage if help requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [architecture]"
    echo ""
    echo "Install OpenZFS macOS 2.3.0 for the specified architecture"
    echo ""
    echo "Arguments:"
    echo "  architecture    Target architecture (x86_64, arm64, or auto-detect)"
    echo ""
    echo "Examples:"
    echo "  $0              # Auto-detect current architecture"
    echo "  $0 x86_64       # Build for Intel"
    echo "  $0 arm64        # Build for Apple Silicon"
    exit 0
fi

# Run main function
main "$@"
