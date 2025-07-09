# Device Support Guide

This guide covers supported devices and how to add support for new devices in the Android 16 AOSP build system.

## Currently Supported Devices

### Google Pixel Devices

| Device | Codename | Architecture | Android 16 Support | Notes |
|--------|----------|--------------|-------------------|-------|
| Pixel 6 | `pixel6` | arm64 | ✅ Full | Tensor SoC |
| Pixel 6 Pro | `pixel6pro` | arm64 | ✅ Full | Tensor SoC |
| Pixel 7 | `pixel7` | arm64 | ✅ Full | Tensor G2 SoC |
| Pixel 7 Pro | `pixel7pro` | arm64 | ✅ Full | Tensor G2 SoC |
| Pixel 8 | `pixel8` | arm64 | ✅ Full | Tensor G3 SoC |
| Pixel 8 Pro | `pixel8pro` | arm64 | ✅ Full | Tensor G3 SoC |

### OnePlus Devices

| Device | Codename | Architecture | Android 16 Support | Notes |
|--------|----------|--------------|-------------------|-------|
| OnePlus 9 | `oneplus9` | arm64 | ✅ Full | Snapdragon 888 |
| OnePlus 9 Pro | `oneplus9pro` | arm64 | ✅ Full | Snapdragon 888 |
| OnePlus 10 Pro | `oneplus10pro` | arm64 | ✅ Full | Snapdragon 8 Gen 1 |
| OnePlus 11 | `oneplus11` | arm64 | ✅ Full | Snapdragon 8 Gen 2 |

### Samsung Galaxy Devices

| Device | Codename | Architecture | Android 16 Support | Notes |
|--------|----------|--------------|-------------------|-------|
| Galaxy S21 | `samsung_s21` | arm64 | ⚠️ Partial | Exynos/Snapdragon variants |
| Galaxy S22 | `samsung_s22` | arm64 | ⚠️ Partial | Exynos/Snapdragon variants |
| Galaxy S23 | `samsung_s23` | arm64 | ✅ Full | Snapdragon 8 Gen 2 |
| Galaxy S24 | `samsung_s24` | arm64 | ✅ Full | Snapdragon 8 Gen 3 |

### Xiaomi Devices

| Device | Codename | Architecture | Android 16 Support | Notes |
|--------|----------|--------------|-------------------|-------|
| Mi 11 | `xiaomi_mi11` | arm64 | ✅ Full | Snapdragon 888 |
| Mi 12 | `xiaomi_mi12` | arm64 | ✅ Full | Snapdragon 8 Gen 1 |
| Mi 13 | `xiaomi_mi13` | arm64 | ✅ Full | Snapdragon 8 Gen 2 |
| Redmi Note 12 Pro | `redmi_note12pro` | arm64 | ⚠️ Partial | MediaTek Dimensity |

### Nothing Devices

| Device | Codename | Architecture | Android 16 Support | Notes |
|--------|----------|--------------|-------------------|-------|
| Nothing Phone (1) | `nothing_phone1` | arm64 | ✅ Full | Snapdragon 778G+ |
| Nothing Phone (2) | `nothing_phone2` | arm64 | ✅ Full | Snapdragon 8+ Gen 1 |

## Support Levels

- ✅ **Full Support**: Complete Android 16 AOSP build with all features
- ⚠️ **Partial Support**: Builds successfully but some features may not work
- ❌ **No Support**: Device not compatible or lacks proper device tree

## Adding New Device Support

### Prerequisites

1. **Device Tree**: Official or community-maintained device tree for Android 16
2. **Vendor Blobs**: Proprietary binaries for hardware functionality
3. **Kernel Source**: Compatible kernel source code
4. **Hardware Documentation**: SoC specifications and hardware details

### Step 1: Create Device Configuration

```bash
# Create device configuration directory
mkdir -p device_configs/manufacturer_codename

# Create basic device config
cat > device_configs/manufacturer_codename/device_config.sh << 'EOF'
#!/bin/bash

# Device Configuration for [Device Name]
DEVICE_MANUFACTURER="manufacturer"
DEVICE_CODENAME="codename"
DEVICE_NAME="Device Name"

# Build configuration
TARGET_ARCH="arm64"
TARGET_CPU_ABI="arm64-v8a"
TARGET_CPU_ABI2=""

# Partition sizes (in bytes)
BOARD_BOOTIMAGE_PARTITION_SIZE=67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE=67108864
BOARD_SYSTEMIMAGE_PARTITION_SIZE=3221225472
BOARD_USERDATAIMAGE_PARTITION_SIZE=10737418240

# Additional build flags
TARGET_USES_64_BIT_BINDER=true
TARGET_SUPPORTS_32_BIT_APPS=true
TARGET_SUPPORTS_64_BIT_APPS=true

# Custom ROM specific settings
LINEAGE_BUILD_VARIANT="userdebug"
EVOLUTION_BUILD_TYPE="OFFICIAL"
EOF
```

### Step 2: Add Device Tree

```bash
# Option 1: Use existing device tree from ROM
./scripts/integrate_custom_rom.sh lineageos manufacturer_codename

# Option 2: Manual device tree setup
mkdir -p aosp/device/manufacturer/codename
# Copy device tree files to this directory

# Option 3: Clone from GitHub
cd aosp/device/manufacturer
git clone https://github.com/LineageOS/android_device_manufacturer_codename codename
```

### Step 3: Add Vendor Blobs

```bash
# Create vendor directory
mkdir -p aosp/vendor/manufacturer/codename

# Option 1: Extract from device
adb root
adb shell
# Use extract-files.sh script from device tree

# Option 2: Download pre-built vendor
# Check TheMuppets or other vendor blob repositories
cd aosp/vendor/manufacturer
git clone https://github.com/TheMuppets/proprietary_vendor_manufacturer codename
```

### Step 4: Add Kernel Source

```bash
# Clone kernel source
mkdir -p aosp/kernel/manufacturer/codename
cd aosp/kernel/manufacturer/codename
git clone https://github.com/manufacturer/kernel_codename .

# Or add to local manifest
cat >> aosp/.repo/local_manifests/local_manifest.xml << 'EOF'
<project name="manufacturer/kernel_codename" 
         path="kernel/manufacturer/codename" 
         remote="github" 
         revision="android-16" />
EOF
```

### Step 5: Test Build

```bash
# Test device configuration
./scripts/build_android.sh manufacturer_codename userdebug --check-only

# Perform actual build
./scripts/build_android.sh manufacturer_codename userdebug
```

## Device-Specific Configurations

### Snapdragon Devices

```bash
# Common Snapdragon settings
TARGET_BOARD_PLATFORM="msm8998"  # or appropriate platform
TARGET_BOOTLOADER_BOARD_NAME="msm8998"
BOARD_VENDOR_QCOM_GPS_LOC_API_HARDWARE="default"
```

### MediaTek Devices

```bash
# Common MediaTek settings
TARGET_BOARD_PLATFORM="mt6893"  # or appropriate platform
BOARD_USES_MTK_HARDWARE=true
BOARD_CONNECTIVITY_VENDOR="MediaTek"
```

### Exynos Devices

```bash
# Common Exynos settings
TARGET_BOARD_PLATFORM="exynos9820"  # or appropriate platform
TARGET_SLSI_VARIANT="bsp"
TARGET_SOC="exynos9820"
```

## Custom ROM Compatibility

### LineageOS Support

Most devices supported by LineageOS 21+ can be adapted for Android 16 AOSP:

```bash
# Check LineageOS device support
curl -s https://wiki.lineageos.org/devices/ | grep "your_device"

# Use LineageOS device tree as base
./scripts/integrate_custom_rom.sh lineageos your_device
```

### Evolution X Support

```bash
# Evolution X typically follows LineageOS device trees
./scripts/integrate_custom_rom.sh evolutionx your_device
```

### crDroid Support

```bash
# crDroid has extensive device support
./scripts/integrate_custom_rom.sh crdroid your_device
```

## Troubleshooting Device Support

### Common Issues

1. **Missing Device Tree**
   ```bash
   # Error: No rule to make target 'device/manufacturer/codename'
   # Solution: Ensure device tree is properly cloned and configured
   ```

2. **Vendor Blob Issues**
   ```bash
   # Error: Missing proprietary files
   # Solution: Extract vendor blobs or download from repository
   ```

3. **Kernel Compilation Errors**
   ```bash
   # Error: Kernel build failures
   # Solution: Check kernel source compatibility and configuration
   ```

### Debug Commands

```bash
# Check available devices
cd aosp
source build/envsetup.sh
lunch

# Verify device configuration
cd device/manufacturer/codename
cat AndroidProducts.mk
cat device.mk

# Check vendor files
ls -la vendor/manufacturer/codename/
```

## Contributing Device Support

### Submitting New Device Support

1. **Test thoroughly** on actual hardware
2. **Document any issues** or limitations
3. **Create pull request** with device configuration
4. **Provide build logs** and test results

### Device Support Template

```bash
# Copy template for new device
cp -r device_configs/template device_configs/manufacturer_codename
# Edit configuration files
# Test build process
# Submit for review
```

## Hardware Requirements by Device Type

### Flagship Devices (2022+)
- **RAM**: 8GB+ recommended for building
- **Storage**: 500GB+ free space
- **Build Time**: 2-4 hours on modern hardware

### Mid-range Devices
- **RAM**: 6GB+ recommended for building  
- **Storage**: 400GB+ free space
- **Build Time**: 3-6 hours on modern hardware

### Older Devices (Pre-2020)
- **Compatibility**: May require Android 16 backports
- **Support**: Limited, community-dependent
- **Build Time**: Varies significantly

## Device Testing Checklist

After successful build:

- [ ] Device boots to Android 16
- [ ] Basic UI functionality works
- [ ] WiFi connectivity
- [ ] Mobile data (if applicable)
- [ ] Bluetooth functionality
- [ ] Camera operation
- [ ] Audio playback/recording
- [ ] Sensors (accelerometer, gyroscope, etc.)
- [ ] Charging functionality
- [ ] USB connectivity
- [ ] Fingerprint/Face unlock (if supported)

## Getting Help

### Community Resources

- **XDA Developers**: Device-specific forums
- **Telegram Groups**: ROM development communities
- **GitHub Issues**: Device tree repositories
- **Reddit**: r/LineageOS, r/AndroidDev

### Official Documentation

- [Android Device Tree Guide](https://source.android.com/docs/setup/build/devices)
- [AOSP Building](https://source.android.com/docs/setup/build)
- [Kernel Building](https://source.android.com/docs/setup/build/building-kernels)
