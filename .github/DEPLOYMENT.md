# ZetaWatch CI/CD Deployment Guide

This document explains how to set up and use the GitHub Actions workflows for building ZetaWatch for both Intel and Apple Silicon architectures.

## Workflows Overview

### 1. `build.yml` - Continuous Integration
- **Triggers**: Push to main/master, Pull Requests, Manual dispatch
- **Purpose**: Build and test on every code change
- **Outputs**: Development builds for both architectures
- **Signing**: Disabled (for CI speed)

### 2. `release.yml` - Release Builds
- **Triggers**: GitHub Releases, Manual dispatch with version
- **Purpose**: Create signed, notarized release builds
- **Outputs**: Production-ready binaries
- **Signing**: Enabled (if certificates provided)

## Architecture Support

| Architecture | Runner | Xcode Target | ZFS Libraries Required |
|--------------|--------|-------------|----------------------|
| Intel (x86_64) | `macos-13` | `x86_64` | OpenZFS x86_64 |
| Apple Silicon (ARM64) | `macos-14` | `arm64` | OpenZFS ARM64 |

## Setup Instructions

### 1. Repository Secrets

For release builds with code signing and notarization, configure these GitHub repository secrets:

#### Code Signing (Optional but Recommended)
```
DEVELOPER_ID_APPLICATION_CERTIFICATE   # Base64-encoded .p12 file
DEVELOPER_ID_APPLICATION_PRIVATE_KEY   # Base64-encoded private key
DEVELOPER_ID_INSTALLER_CERTIFICATE     # Base64-encoded installer cert (optional)
DEVELOPER_ID_INSTALLER_PRIVATE_KEY     # Base64-encoded installer key (optional)
KEYCHAIN_PASSWORD                      # Password for temporary keychain
```

#### Notarization (Optional but Recommended)
```
NOTARIZATION_USERNAME                  # Apple ID email
NOTARIZATION_PASSWORD                  # App-specific password
NOTARIZATION_TEAM_ID                   # Apple Developer Team ID
```

### 2. Preparing Certificates

To create the base64-encoded certificates:

```bash
# Export certificate from Keychain (include private key)
# Then encode for GitHub secrets:
base64 -i DeveloperID_Application.p12 | pbcopy
```

### 3. ZFS Dependencies Setup

The workflows automatically install OpenZFS macOS 2.3.0 from the [openzfsonosx fork](https://github.com/openzfsonosx/openzfs-fork/releases/tag/zfs-macOS-2.3.0) using our custom installation script.

#### Automatic OpenZFS Installation:

The `.github/scripts/install-openzfs.sh` script:
1. Downloads OpenZFS macOS 2.3.0 source code
2. Builds it for the target architecture (Intel/Apple Silicon)
3. Installs libraries to `/usr/local/zfs/`
4. Creates version-specific symbolic links for ZetaWatch compatibility

#### Manual Installation:

For local development, you can also install OpenZFS manually:
```bash
# Install for current architecture
./.github/scripts/install-openzfs.sh

# Install for specific architecture
./.github/scripts/install-openzfs.sh x86_64  # Intel
./.github/scripts/install-openzfs.sh arm64   # Apple Silicon
```

## Usage

### Development Builds (CI)

Builds trigger automatically on:
- Push to `main` or `master` branch
- Pull request creation/updates

Manual trigger:
1. Go to Actions tab in GitHub
2. Select "Build ZetaWatch" workflow
3. Click "Run workflow"

### Release Builds

#### Option 1: GitHub Release
1. Create a new release in GitHub
2. Use a version tag like `v1.0.0`
3. Workflow automatically builds and attaches binaries

#### Option 2: Manual Dispatch
1. Go to Actions tab
2. Select "Release Build" workflow
3. Click "Run workflow"
4. Enter version (e.g., `v1.0.0`)

## Build Outputs

### CI Builds
- `ZetaWatch-Intel.zip` - Intel build
- `ZetaWatch-Apple-Silicon.zip` - Apple Silicon build
- `ZetaWatch-Universal-Release/` - Combined package

### Release Builds
- `ZetaWatch-v1.0.0-intel.zip` - Signed Intel build
- `ZetaWatch-v1.0.0-apple-silicon.zip` - Signed Apple Silicon build
- `*.sha256` files - Checksums for verification
- Combined universal release package

## Troubleshooting

### Common Issues

1. **ZFS Libraries Not Found**
   - Implement actual ZFS library installation steps
   - Ensure libraries match the target architecture

2. **Code Signing Failures**
   - Verify certificate secrets are correctly base64 encoded
   - Ensure certificates are valid and not expired
   - Check Team ID matches your Apple Developer account

3. **Architecture Mismatch**
   - Ensure ZFS libraries match Xcode target architecture
   - Verify Sparkle framework supports target architecture

4. **Build Timeouts**
   - Large builds may timeout on free GitHub runners
   - Consider using self-hosted runners for faster builds

### Debug Steps

1. **Check Build Logs**
   ```yaml
   - name: Debug environment
     run: |
       uname -m
       file /usr/local/zfs/lib/*.dylib
       lipo -info ThirdParty/Sparkle/Sparkle.framework/Sparkle
   ```

2. **Validate Dependencies**
   ```yaml
   - name: Check dependencies
     run: |
       otool -L build/Release/ZetaWatch.app/Contents/MacOS/ZetaWatch
   ```

## Advanced Configuration

### Custom Xcode Settings

Add custom build settings to the workflow:

```yaml
- name: Build with custom settings
  run: |
    xcodebuild build \
      -project "$XCODE_PROJECT" \
      -scheme "$SCHEME" \
      -configuration "$BUILD_CONFIGURATION" \
      -arch "${{ matrix.xcode_arch }}" \
      MACOSX_DEPLOYMENT_TARGET=11.0 \
      ENABLE_HARDENED_RUNTIME=YES \
      OTHER_CFLAGS="-DCUSTOM_FLAG" \
      -quiet
```

### Matrix Expansion

Add more build variants:

```yaml
strategy:
  matrix:
    include:
      - arch: Intel-Debug
        os: macos-13
        xcode_arch: x86_64
        configuration: Debug
      - arch: Intel-Release
        os: macos-13
        xcode_arch: x86_64
        configuration: Release
      # ... etc
```

## Security Considerations

1. **Secrets Management**
   - Never commit certificates or passwords to the repository
   - Use GitHub secrets for all sensitive data
   - Rotate secrets regularly

2. **Code Signing**
   - Always sign release builds
   - Use Developer ID certificates for distribution outside App Store
   - Enable Hardened Runtime for security

3. **Notarization**
   - Required for macOS Gatekeeper compatibility
   - Use app-specific passwords, not your main Apple ID password
   - Test notarized builds on clean systems

## Performance Optimization

1. **Caching**
   ```yaml
   - name: Cache Sparkle
     uses: actions/cache@v3
     with:
       path: ThirdParty/Sparkle/Sparkle.framework
       key: sparkle-2.7.1-${{ runner.os }}
   ```

2. **Parallel Builds**
   - Matrix builds run in parallel automatically
   - Consider splitting large projects into multiple schemes

3. **Conditional Steps**
   ```yaml
   - name: Expensive step
     if: github.event_name == 'release'
     run: |
       # Only run on releases
   ```

This setup provides a robust CI/CD pipeline for building ZetaWatch across both major Mac architectures while maintaining flexibility for different deployment scenarios.
