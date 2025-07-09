# Android 16 AOSP Build Troubleshooting Guide

This guide covers common issues and solutions when building Android 16 AOSP with custom ROM integration.

## Common Build Errors

### 1. Out of Memory Errors

**Symptoms:**
- Build fails with "virtual memory exhausted" or "Cannot allocate memory"
- System becomes unresponsive during build

**Solutions:**
```bash
# Reduce parallel jobs
./scripts/build_android.sh -j4

# Add swap space (temporary fix)
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanent swap (add to /etc/fstab)
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. Disk Space Issues

**Symptoms:**
- "No space left on device" errors
- Build stops unexpectedly

**Solutions:**
```bash
# Check disk usage
df -h
du -sh aosp/ custom_roms/ out/

# Clean build artifacts
./scripts/build_android.sh --clean

# Clean ccache
ccache -C

# Remove old ROM sources
rm -rf custom_roms/unused_rom_name
```

### 3. Java Version Issues

**Symptoms:**
- "Unsupported major.minor version" errors
- Java compilation failures

**Solutions:**
```bash
# Check Java version
java -version
javac -version

# Switch to Java 11 (required for Android 16)
sudo update-alternatives --config java
sudo update-alternatives --config javac

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
```

### 4. Repo Sync Failures

**Symptoms:**
- "fatal: unable to access" errors
- Incomplete source downloads

**Solutions:**
```bash
# Resume interrupted sync
cd aosp
repo sync -c -j4 --force-sync

# Reset corrupted repositories
repo forall -c 'git reset --hard'
repo sync -c -j4

# Use different manifest branch
repo init -u https://android.googlesource.com/platform/manifest -b android-latest-release
```

### 5. Custom ROM Integration Issues

**Symptoms:**
- ROM-specific features not working
- Build conflicts between AOSP and ROM

**Solutions:**
```bash
# Check ROM compatibility
./scripts/integrate_custom_rom.sh lineageos --check-only

# Manual conflict resolution
cd aosp
git status
git diff

# Reset to clean state
repo forall -c 'git clean -fd'
repo forall -c 'git reset --hard'
```

## Performance Optimization

### 1. Enable ccache

```bash
# Set ccache size (recommended: 100GB)
ccache -M 100G

# Check ccache stats
ccache -s

# Enable ccache in build
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
```

### 2. Optimize Build Jobs

```bash
# Formula: (CPU cores * 1.5) but not more than available RAM/2GB
# Example for 16 cores, 32GB RAM:
./scripts/build_android.sh -j16

# For systems with limited RAM:
./scripts/build_android.sh -j4
```

### 3. Use Ninja Build System

```bash
# Enable ninja (usually default in Android 16)
export USE_NINJA=true
```

## Network Issues

### 1. Slow Downloads

```bash
# Use fewer parallel jobs for repo sync
repo sync -c -j2

# Use local mirror (if available)
repo init -u /path/to/local/mirror/manifest.git
```

### 2. Proxy Configuration

```bash
# Set proxy for repo
export HTTP_PROXY=http://proxy:port
export HTTPS_PROXY=http://proxy:port

# Git proxy configuration
git config --global http.proxy http://proxy:port
git config --global https.proxy http://proxy:port
```

## Device-Specific Issues

### 1. Missing Device Tree

**Symptoms:**
- "No rule to make target" errors for device-specific files
- Device not found in lunch menu

**Solutions:**
```bash
# Check available devices
cd aosp
source build/envsetup.sh
lunch

# Add device tree manually
mkdir -p device/manufacturer/codename
# Copy device tree from ROM or create minimal one
```

### 2. Missing Vendor Blobs

**Symptoms:**
- Missing proprietary libraries
- Hardware features not working

**Solutions:**
```bash
# Extract vendor blobs from device
adb root
adb shell
# Use proprietary-files.txt to extract needed files

# Or use pre-built vendor image
# Download from device manufacturer or ROM
```

## Build Environment Issues

### 1. Ubuntu Version Compatibility

```bash
# Check Ubuntu version
lsb_release -a

# For older Ubuntu versions, use Docker
docker run -it ubuntu:20.04
# Setup build environment inside container
```

### 2. Missing Dependencies

```bash
# Install missing packages
sudo apt-get update
sudo apt-get install -y \
    git-core gnupg flex bison build-essential zip curl \
    zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev \
    lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip \
    fontconfig python3 python3-pip bc rsync

# For specific errors, install additional packages as needed
```

## Debugging Build Issues

### 1. Verbose Build Output

```bash
# Enable verbose output
./scripts/build_android.sh -j1 V=1

# Show commands being executed
./scripts/build_android.sh VERBOSE=1
```

### 2. Build Log Analysis

```bash
# Save build log
./scripts/build_android.sh 2>&1 | tee build.log

# Search for specific errors
grep -i error build.log
grep -i "failed" build.log
```

### 3. Incremental Build Issues

```bash
# Clean specific module
cd aosp
m clean-module_name

# Clean and rebuild specific target
m clean-systemimage
m systemimage
```

## Recovery Procedures

### 1. Complete Reset

```bash
# Nuclear option - start fresh
rm -rf aosp custom_roms out
./scripts/download_aosp.sh
```

### 2. Partial Reset

```bash
# Reset AOSP only
cd aosp
repo forall -c 'git clean -fd'
repo forall -c 'git reset --hard'
repo sync -c
```

### 3. Backup Important Files

```bash
# Before major changes, backup:
tar -czf backup_$(date +%Y%m%d).tar.gz \
    build_config.sh \
    device_configs/ \
    patches/ \
    local_manifest.xml
```

## Getting Help

### 1. Log Collection

```bash
# Collect system info
./scripts/collect_build_info.sh > build_info.txt

# Include in bug reports:
# - build_info.txt
# - build.log (last 100 lines)
# - Steps to reproduce
```

### 2. Community Resources

- **XDA Developers**: Device-specific forums
- **LineageOS Wiki**: Device trees and build guides  
- **Android Building Group**: Telegram/Discord communities
- **Stack Overflow**: Technical programming issues
- **GitHub Issues**: ROM-specific problems

### 3. Official Documentation

- [Android Source](https://source.android.com/)
- [LineageOS Build Guide](https://wiki.lineageos.org/build_guides)
- [AOSP Building](https://source.android.com/docs/setup/build)

## Prevention Tips

1. **Always check prerequisites** before starting builds
2. **Monitor disk space** during long builds  
3. **Use ccache** for faster incremental builds
4. **Keep backups** of working configurations
5. **Test with clean builds** before releasing
6. **Document custom changes** for future reference
7. **Stay updated** with ROM and AOSP changes
