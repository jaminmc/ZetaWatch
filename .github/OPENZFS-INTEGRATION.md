# OpenZFS macOS 2.3.0 Integration

This document explains how ZetaWatch's GitHub Actions workflows integrate with OpenZFS macOS 2.3.0 from the [openzfsonosx fork](https://github.com/openzfsonosx/openzfs-fork/releases/tag/zfs-macOS-2.3.0).

## Overview

The GitHub Actions workflows automatically download, build, and install OpenZFS 2.3.0 for the target architecture during the CI/CD process. This ensures that ZetaWatch can be built with the correct ZFS libraries for both Intel and Apple Silicon Macs.

## Integration Components

### 1. Installation Script
**File**: `.github/scripts/install-openzfs.sh`

This script handles the complete OpenZFS installation process:
- Downloads OpenZFS macOS 2.3.0 source from the openzfsonosx fork
- Configures the build for the target architecture (x86_64 or arm64)
- Builds the userland libraries and tools
- Installs to `/usr/local/zfs/`
- Creates symbolic links for library version compatibility

### 2. Workflow Integration
**Files**: `.github/workflows/build.yml`, `.github/workflows/release.yml`

Both workflows include:
- Caching of built OpenZFS libraries (speeds up subsequent builds)
- Conditional installation (only builds if cache miss)
- Architecture-specific builds for Intel and Apple Silicon
- Verification steps to ensure installation succeeded

### 3. Local Development Support
**File**: `.github/scripts/build-local.sh` (updated)

The local build script now:
- Checks for existing ZFS installation
- Offers to install OpenZFS automatically if missing
- Handles library version mismatches
- Provides interactive installation prompts

## OpenZFS macOS 2.3.0 Features

From the [release page](https://github.com/openzfsonosx/openzfs-fork/releases/tag/zfs-macOS-2.3.0), this version includes:

### Major Features
- **RAIDZ Expansion**: Add new devices to existing RAIDZ pools without downtime
- **Fast Dedup**: Major performance upgrade to deduplication functionality  
- **Direct IO**: Bypass ARC for reads/writes, improving NVMe performance
- **JSON Output**: Optional JSON output for common commands
- **Long Names**: Support for file/directory names up to 1023 characters

### Platform Support
- **macOS**: 10.9 (Mavericks) - 15.0 (Sequoia)
- **Linux**: kernels 4.18 - 6.12
- **FreeBSD**: releases 13.3, 14.0 - 14.2

### Bug Fixes
- Series of critical bug fixes from previous versions
- Numerous performance improvements throughout the codebase

## Architecture-Specific Builds

### Intel (x86_64)
```bash
# Configure flags
CFLAGS="-arch x86_64"
CXXFLAGS="-arch x86_64" 
LDFLAGS="-arch x86_64"

# Runs on macos-13 GitHub runners
```

### Apple Silicon (arm64)
```bash
# Configure flags
CFLAGS="-arch arm64"
CXXFLAGS="-arch arm64"
LDFLAGS="-arch arm64"

# Runs on macos-14 GitHub runners
```

## Library Compatibility

ZetaWatch expects specific library versions. The installation script creates symbolic links:

| Expected by ZetaWatch | Actual OpenZFS File | Purpose |
|----------------------|--------------------| --------|
| `libzfs.6.dylib` | `libzfs.dylib` | Core ZFS library |
| `libzpool.6.dylib` | `libzpool.dylib` | Pool management |
| `libzfs_core.3.dylib` | `libzfs_core.dylib` | Core operations |
| `libnvpair.3.dylib` | `libnvpair.dylib` | Name-value pairs |

## Build Process Flow

### 1. Cache Check
```yaml
- name: Cache OpenZFS libraries
  uses: actions/cache@v4
  with:
    path: /usr/local/zfs
    key: openzfs-2.3.0-${{ matrix.xcode_arch }}-${{ runner.os }}
```

### 2. Installation (if cache miss)
```yaml
- name: Install ZFS dependencies
  if: steps.cache-openzfs.outputs.cache-hit != 'true'
  run: |
    ./.github/scripts/install-openzfs.sh ${{ matrix.xcode_arch }}
```

### 3. Verification
```yaml
- name: Verify ZFS installation
  run: |
    ls -la /usr/local/zfs/lib/
    file /usr/local/zfs/lib/libzfs.6.dylib
```

### 4. ZetaWatch Build
```yaml
- name: Build ZetaWatch
  run: |
    xcodebuild build \
      -project "$XCODE_PROJECT" \
      -arch "${{ matrix.xcode_arch }}" \
      # ... other flags
```

## Performance Optimizations

### 1. Caching Strategy
- **Cache Key**: `openzfs-2.3.0-{architecture}-{os}`
- **Cache Path**: `/usr/local/zfs` (complete installation)
- **Cache Duration**: Until OpenZFS version changes
- **Benefit**: ~15-20 minute build time reduction

### 2. Parallel Builds
- Uses all available CPU cores: `make -j$(sysctl -n hw.logicalcpu)`
- Matrix builds run in parallel for both architectures
- Typical build time: 10-15 minutes (first time), 2-3 minutes (cached)

### 3. Conditional Installation
- Only builds when cache miss occurs
- Verification step ensures installation integrity
- Automatic retry logic in local development script

## Local Development Usage

### Quick Installation
```bash
# Install for current architecture
./.github/scripts/install-openzfs.sh

# Install for specific architecture  
./.github/scripts/install-openzfs.sh arm64
```

### Build with Auto-Install
```bash
# Build script will offer to install OpenZFS if missing
./.github/scripts/build-local.sh current
```

### Manual Verification
```bash
# Check installation
ls -la /usr/local/zfs/lib/
file /usr/local/zfs/lib/libzfs.6.dylib
lipo -info /usr/local/zfs/lib/libzfs.6.dylib
```

## Troubleshooting

### Common Issues

#### 1. Build Fails - Missing Dependencies
```bash
# Install build tools
xcode-select --install

# Install autotools (if using Homebrew)
brew install autoconf automake libtool
```

#### 2. Architecture Mismatch
```bash
# Check library architecture
file /usr/local/zfs/lib/libzfs.6.dylib

# Should show: Mach-O 64-bit dynamically linked shared library arm64
# Or: Mach-O 64-bit dynamically linked shared library x86_64
```

#### 3. Permission Issues
```bash
# Installation requires sudo for /usr/local/zfs
# Ensure script has sudo permissions in CI
```

#### 4. Cache Issues in CI
```bash
# Clear cache if needed
# Go to GitHub Actions -> Caches -> Delete old OpenZFS caches
```

### Debug Commands

```bash
# Show build environment
uname -m                    # Current architecture
xcodebuild -version        # Xcode version
xcodebuild -showsdks       # Available SDKs

# Check ZFS installation
otool -L /usr/local/zfs/lib/libzfs.6.dylib    # Library dependencies
nm /usr/local/zfs/lib/libzfs.6.dylib | head   # Exported symbols

# Verify ZetaWatch linking
otool -L build/Release/ZetaWatch.app/Contents/MacOS/ZetaWatch | grep zfs
```

## Security Considerations

### 1. Source Verification
- Downloads from official openzfsonosx GitHub releases
- Uses HTTPS for all downloads
- Verifies source directory structure

### 2. Build Isolation
- Builds in temporary directories
- Cleans up after installation
- No network access during build phase

### 3. Installation Security
- Uses sudo only for system directory installation
- Maintains file permissions and ownership
- No modification of system frameworks

## Maintenance

### Updating OpenZFS Version
1. Update `OPENZFS_VERSION` in `install-openzfs.sh`
2. Update `OPENZFS_URL` to new release
3. Test build locally for both architectures
4. Update cache keys in workflows
5. Update documentation references

### Testing New Versions
```bash
# Test installation script
./.github/scripts/install-openzfs.sh --help

# Test local build
./.github/scripts/build-local.sh both

# Verify library compatibility
otool -L /usr/local/zfs/lib/*.dylib
```

This integration provides a robust, automated way to build ZetaWatch with the latest OpenZFS features while maintaining compatibility across Intel and Apple Silicon architectures.
