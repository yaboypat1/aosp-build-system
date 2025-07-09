# Android 16 AOSP Build with Custom ROM Integration

This project sets up a complete Android 16 AOSP build environment with custom ROM integration capabilities.

## Prerequisites

### Hardware Requirements
- **CPU**: 64-bit x86 system (minimum 8 cores, recommended 16+ cores)
- **RAM**: Minimum 64 GB (Google uses 72-core machines with 64 GB RAM)
- **Storage**: At least 400 GB free space (250 GB for source + 150 GB for build)
- **OS**: Ubuntu 18.04+ or other 64-bit Linux distribution with glibc 2.17+

### Build Time Estimates
- **High-end (16+ cores, 64GB RAM)**: ~2-3 hours full build
- **Mid-range (8 cores, 32GB RAM)**: ~6-8 hours full build
- **Incremental builds**: 5-15 minutes

## Supported Custom ROMs

This setup supports integration with popular Android 16 compatible custom ROMs:

### AOSP-Based ROMs
- **LineageOS**: Most popular custom ROM with extensive device support
- **Evolution X**: Feature-rich ROM with Pixel-like experience
- **crDroid**: Smooth performance with customization options
- **ArrowOS**: Clean AOSP experience with useful additions
- **PixelExperience**: Pure Pixel experience for non-Pixel devices

### Privacy-Focused ROMs
- **GrapheneOS**: Security and privacy hardened
- **CalyxOS**: Privacy-focused with microG support
- **DivestOS**: Security-focused fork of LineageOS

## Quick Start

1. **Setup Environment**:
   ```bash
   ./scripts/setup_environment.sh
   ```

2. **Download AOSP Source**:
   ```bash
   ./scripts/download_aosp.sh
   ```

3. **Integrate Custom ROM**:
   ```bash
   ./scripts/integrate_custom_rom.sh [ROM_NAME]
   ```

4. **Build Android**:
   ```bash
   ./scripts/build_android.sh [TARGET_DEVICE]
   ```

## Directory Structure

```
android/
├── aosp/                    # AOSP source code
├── custom_roms/            # Custom ROM sources
├── device_configs/         # Device-specific configurations
├── scripts/               # Build and setup scripts
├── patches/               # Custom patches
├── out/                   # Build output
└── tools/                 # Additional build tools
```

## Supported Devices

The build system supports various device targets:
- Generic x86/x86_64 (for emulator)
- Pixel devices (6, 7, 8, 9 series)
- Popular devices with custom ROM support

## Custom ROM Integration

Each custom ROM is integrated as a separate branch/overlay:
- ROM-specific patches are applied automatically
- Device trees are merged from ROM repositories
- Vendor blobs are handled per ROM requirements

## Build Variants

- **eng**: Engineering build (debug, root access)
- **userdebug**: User debug build (debuggable, no root by default)
- **user**: Production build (optimized, no debug)

## Security Considerations

- All ROM sources are verified against known repositories
- Checksums are validated for downloaded components
- Build reproducibility is maintained where possible

## Troubleshooting

Common issues and solutions are documented in `docs/troubleshooting.md`

## Contributing

See `CONTRIBUTING.md` for guidelines on contributing to this build system.

## License

This project follows AOSP licensing. Individual ROM components maintain their respective licenses.
