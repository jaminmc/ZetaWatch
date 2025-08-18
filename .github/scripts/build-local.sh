#!/bin/bash

# Local build script for testing CI workflows
# Usage: ./build-local.sh [intel|arm64|both]

set -e

# Configuration
XCODE_PROJECT="ZetaWatch.xcodeproj"
SCHEME="ZetaWatch"
BUILD_CONFIGURATION="Release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to detect current architecture
detect_arch() {
    local arch=$(uname -m)
    if [ "$arch" = "arm64" ]; then
        echo "arm64"
    else
        echo "x86_64"
    fi
}



# Function to check ZFS dependencies
check_zfs() {
    log_info "Checking ZFS dependencies..."
    
    local zfs_lib_dir="/usr/local/zfs/lib"
    
    if [ ! -d "$zfs_lib_dir" ]; then
        log_warning "ZFS not found at $zfs_lib_dir"
        
        # Offer to install OpenZFS
        read -p "Would you like to install OpenZFS automatically? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing OpenZFS..."
            ./.github/scripts/install-openzfs.sh
            return $?
        else
            log_warning "Skipping ZFS installation - build may fail"
            return 1
        fi
    fi
    
    # Check for required libraries
    local required_libs=("libzfs.6.dylib" "libzpool.6.dylib" "libzfs_core.3.dylib" "libnvpair.3.dylib")
    local missing_libs=()
    
    for lib in "${required_libs[@]}"; do
        if [ ! -f "$zfs_lib_dir/$lib" ]; then
            missing_libs+=("$lib")
        fi
    done
    
    if [ ${#missing_libs[@]} -eq 0 ]; then
        log_success "All ZFS libraries found"
        
        # Show architecture info
        for lib in "${required_libs[@]}"; do
            if [ -f "$zfs_lib_dir/$lib" ]; then
                echo "  $lib: $(file "$zfs_lib_dir/$lib" | cut -d: -f2 | xargs)"
            fi
        done
        return 0
    else
        log_error "Missing ZFS libraries:"
        for lib in "${missing_libs[@]}"; do
            echo "  - $lib"
        done
        
        # Offer to install/reinstall OpenZFS
        read -p "Would you like to (re)install OpenZFS to fix missing libraries? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing OpenZFS..."
            ./.github/scripts/install-openzfs.sh
            return $?
        else
            return 1
        fi
    fi
}

# Function to build for specific architecture
build_arch() {
    local target_arch="$1"
    local arch_name="$2"
    
    log_info "Building ZetaWatch for $arch_name ($target_arch)..."
    
    # Clean previous builds
    xcodebuild clean \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$BUILD_CONFIGURATION" \
        -quiet
    
    # Build
    xcodebuild build \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$BUILD_CONFIGURATION" \
        -arch "$target_arch" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | tee "build-${target_arch}.log"
    
    # Check if build succeeded
    local app_path=$(find build -name "ZetaWatch.app" -type d | head -1)
    
    if [ -z "$app_path" ]; then
        log_error "Build failed for $arch_name"
        log_error "Check build-${target_arch}.log for details"
        return 1
    fi
    
    # Create output directory
    mkdir -p "dist"
    
    # Copy app and create zip
    local output_name="ZetaWatch-${arch_name}"
    cp -R "$app_path" "dist/${output_name}.app"
    
    cd dist
    zip -r "${output_name}.zip" "${output_name}.app"
    cd ..
    
    # Show binary info
    local binary_path="dist/${output_name}.app/Contents/MacOS/ZetaWatch"
    if [ -f "$binary_path" ]; then
        log_success "Build completed for $arch_name"
        echo "  Binary: $(file "$binary_path" | cut -d: -f2 | xargs)"
        echo "  Size: $(du -h "dist/${output_name}.zip" | cut -f1)"
    fi
    
    return 0
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [intel|arm64|both|current]"
    echo ""
    echo "Options:"
    echo "  intel   - Build for Intel Macs (x86_64)"
    echo "  arm64   - Build for Apple Silicon (arm64)"
    echo "  both    - Build for both architectures"
    echo "  current - Build for current system architecture"
    echo ""
    echo "Examples:"
    echo "  $0 both        # Build universal binaries"
    echo "  $0 current     # Build for this Mac"
    echo "  $0 arm64       # Build for Apple Silicon only"
}

# Main script
main() {
    local target="$1"
    
    # Default to current architecture if no argument provided
    if [ -z "$target" ]; then
        target="current"
    fi
    
    # Show help
    if [ "$target" = "-h" ] || [ "$target" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    log_info "ZetaWatch Local Build Script"
    log_info "Current system: $(uname -m)"
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "$XCODE_PROJECT" ]; then
        log_error "Not in ZetaWatch project directory"
        log_error "Run this script from the project root"
        exit 1
    fi
    
    # Clean previous builds
    rm -rf build dist *.log
    

    
    # Check ZFS (continue even if missing - will fail during build with better error)
    check_zfs || log_warning "ZFS check failed - build may fail"
    
    echo ""
    
    # Build based on target
    local failed_builds=()
    
    case "$target" in
        "intel")
            build_arch "x86_64" "Intel" || failed_builds+=("Intel")
            ;;
        "arm64")
            build_arch "arm64" "Apple-Silicon" || failed_builds+=("Apple-Silicon")
            ;;
        "current")
            local current_arch=$(detect_arch)
            if [ "$current_arch" = "arm64" ]; then
                build_arch "arm64" "Apple-Silicon" || failed_builds+=("Apple-Silicon")
            else
                build_arch "x86_64" "Intel" || failed_builds+=("Intel")
            fi
            ;;
        "both")
            build_arch "x86_64" "Intel" || failed_builds+=("Intel")
            build_arch "arm64" "Apple-Silicon" || failed_builds+=("Apple-Silicon")
            ;;
        *)
            log_error "Unknown target: $target"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    
    # Summary
    if [ ${#failed_builds[@]} -eq 0 ]; then
        log_success "All builds completed successfully!"
        
        if [ -d "dist" ]; then
            echo ""
            log_info "Build artifacts:"
            ls -la dist/
            
            echo ""
            log_info "To test the build:"
            echo "  open dist/ZetaWatch-*.app"
        fi
    else
        log_error "Some builds failed:"
        for failed in "${failed_builds[@]}"; do
            echo "  - $failed"
        done
        
        echo ""
        log_info "Check build logs for details:"
        ls -la *.log 2>/dev/null || true
        
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
