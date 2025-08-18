# ZetaWatch GitHub Actions

This directory contains the CI/CD configuration for building ZetaWatch for both Intel and Apple Silicon architectures.

## Quick Start

### For Developers
1. Push code to trigger automatic builds
2. Check the Actions tab for build status
3. Download build artifacts from successful runs

### For Releases
1. Create a GitHub release with a version tag (e.g., `v1.0.0`)
2. Workflows automatically build and attach binaries
3. Both Intel and Apple Silicon versions are created

### For Local Testing
```bash
# Build for current architecture
./.github/scripts/build-local.sh current

# Build for both architectures
./.github/scripts/build-local.sh both
```

## Files Overview

| File | Purpose |
|------|---------|
| `workflows/build.yml` | CI builds on every push/PR |
| `workflows/release.yml` | Signed release builds |
| `scripts/build-local.sh` | Local testing script |
| `DEPLOYMENT.md` | Detailed setup guide |
| `secrets-template.env` | GitHub secrets configuration |

## Architecture Support

✅ **Intel Macs** (x86_64) - Built on `macos-13` runners  
✅ **Apple Silicon** (ARM64) - Built on `macos-14` runners  
✅ **Universal Distribution** - Combined release packages

## Requirements

### Development Builds (No Setup Required)
- ✅ Builds work out of the box
- ⚠️ Apps are unsigned (Gatekeeper warnings)

### Production Builds (Setup Required)
- 🔐 Apple Developer certificates for code signing
- 📝 App notarization for Gatekeeper compatibility
- 📚 See `DEPLOYMENT.md` for full setup guide

## Build Matrix

| Workflow | Intel | Apple Silicon | Signed | Notarized |
|----------|-------|---------------|--------|-----------|
| CI Build | ✅ | ✅ | ❌ | ❌ |
| Release Build | ✅ | ✅ | ✅* | ✅* |

*\* If certificates are configured*

## Artifacts

### CI Builds
- `ZetaWatch-Intel.zip`
- `ZetaWatch-Apple-Silicon.zip` 
- `ZetaWatch-Universal-Release/` (combined)

### Release Builds
- `ZetaWatch-v1.0.0-intel.zip`
- `ZetaWatch-v1.0.0-apple-silicon.zip`
- `*.sha256` checksum files
- Universal release package with README

## Dependencies

### Automatic
- ✅ **Sparkle Framework** - Downloaded automatically (universal binary)
- ✅ **OpenZFS Libraries** - Built automatically from [openzfsonosx fork](https://github.com/openzfsonosx/openzfs-fork/releases/tag/zfs-macOS-2.3.0)
- ✅ **Xcode/Build Tools** - Provided by GitHub runners

### Optional Setup
- ⚠️ **Code Signing** - Recommended for production releases
- ⚠️ **Notarization** - Recommended for Gatekeeper compatibility

## Common Tasks

### Trigger a Release Build
1. Go to GitHub Actions tab
2. Select "Release Build" workflow  
3. Click "Run workflow"
4. Enter version (e.g., `v1.0.0`)

### Download Build Artifacts
1. Go to GitHub Actions tab
2. Click on a completed workflow run
3. Scroll down to "Artifacts" section
4. Download the zip files

### Test Locally
```bash
# Quick test of current architecture
./.github/scripts/build-local.sh current

# Full test of both architectures  
./.github/scripts/build-local.sh both
```

### Setup Code Signing
1. Copy `.github/secrets-template.env`
2. Follow certificate generation steps
3. Add secrets to GitHub repository settings
4. See `DEPLOYMENT.md` for detailed instructions

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails with ZFS errors | Configure ZFS library installation in workflows |
| Code signing fails | Check certificate secrets are properly base64 encoded |
| Architecture mismatch | Ensure ZFS libraries match target architecture |
| Workflow doesn't trigger | Check branch names in workflow triggers |

## Support

- 📖 **Detailed Guide**: See `DEPLOYMENT.md`
- 🔧 **Local Testing**: Use `scripts/build-local.sh`
- 🐛 **Issues**: Check build logs in GitHub Actions
- 💬 **Questions**: Open a GitHub issue

---

**Note**: This setup requires OpenZFS to be available on the build systems. The workflows include placeholder steps for ZFS installation that need to be implemented based on your distribution method.
