#!/bin/bash

# Custom ROM Integration Script for Android 16 AOSP
# Integrates popular custom ROMs with AOSP base

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ROM configurations
declare -A ROM_CONFIGS
ROM_CONFIGS[lineageos]="https://github.com/LineageOS/android.git lineage-22.1"
ROM_CONFIGS[evolution-x]="https://github.com/Evolution-X/manifest.git udc"
ROM_CONFIGS[crdroid]="https://github.com/crdroidandroid/android.git 15.0"
ROM_CONFIGS[arrow]="https://github.com/ArrowOS/android_manifest.git arrow-15.0"
ROM_CONFIGS[pixel-experience]="https://github.com/PixelExperience/manifest.git fourteen"
ROM_CONFIGS[grapheneos]="https://github.com/GrapheneOS/platform_manifest.git 15"
ROM_CONFIGS[calyxos]="https://github.com/CalyxOS/platform_manifest.git android15"

# Usage function
usage() {
    echo "Usage: $0 <rom_name> [device_codename]"
    echo
    echo "Available ROMs:"
    for rom in "${!ROM_CONFIGS[@]}"; do
        echo "  - $rom"
    done
    echo
    echo "Examples:"
    echo "  $0 lineageos"
    echo "  $0 evolution-x pixel7"
    echo "  $0 crdroid generic"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AOSP is downloaded
    if [ ! -d "aosp" ] || [ ! -f "aosp/build/envsetup.sh" ]; then
        log_error "AOSP source not found. Please run download_aosp.sh first"
        exit 1
    fi
    
    # Check if repo is available
    if ! command -v repo &> /dev/null; then
        log_error "Repo tool not found. Please run setup_environment.sh first"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Download ROM manifest
download_rom_manifest() {
    local rom_name=$1
    local rom_config=${ROM_CONFIGS[$rom_name]}
    
    if [ -z "$rom_config" ]; then
        log_error "Unknown ROM: $rom_name"
        usage
        exit 1
    fi
    
    local manifest_url=$(echo $rom_config | cut -d' ' -f1)
    local branch=$(echo $rom_config | cut -d' ' -f2)
    
    log_info "Downloading $rom_name manifest..."
    log_info "Manifest URL: $manifest_url"
    log_info "Branch: $branch"
    
    # Create ROM directory
    ROM_DIR="custom_roms/$rom_name"
    mkdir -p "$ROM_DIR"
    cd "$ROM_DIR"
    
    # Initialize repo with ROM manifest
    repo init -u "$manifest_url" -b "$branch" --depth=1
    
    log_success "ROM manifest downloaded successfully"
}

# Sync ROM source
sync_rom_source() {
    local rom_name=$1
    
    log_info "Syncing $rom_name source code..."
    log_warning "This may take 30-60 minutes depending on your internet connection"
    
    # Use fewer jobs for ROM sync to avoid server overload
    JOBS=$(nproc)
    if [ "$JOBS" -gt 4 ]; then
        JOBS=4
    fi
    
    log_info "Using $JOBS parallel jobs for ROM sync"
    
    # Sync ROM source
    repo sync -c -j"$JOBS" --force-sync --no-tags --no-clone-bundle --optimized-fetch --prune
    
    log_success "$rom_name source sync completed"
}

# Create ROM integration patches
create_integration_patches() {
    local rom_name=$1
    
    log_info "Creating integration patches for $rom_name..."
    
    cd ../../  # Back to main directory
    
    # Create patches directory for this ROM
    PATCHES_DIR="patches/$rom_name"
    mkdir -p "$PATCHES_DIR"
    
    # Create integration script for this ROM
    cat > "$PATCHES_DIR/integrate.sh" << EOF
#!/bin/bash

# $rom_name Integration Script
# This script integrates $rom_name changes with AOSP

set -e

ROM_NAME="$rom_name"
AOSP_DIR="aosp"
ROM_DIR="custom_roms/\$ROM_NAME"

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m \$1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m \$1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m \$1"
}

# Copy ROM-specific files
copy_rom_files() {
    log_info "Copying \$ROM_NAME specific files..."
    
    # Copy vendor overlays if they exist
    if [ -d "\$ROM_DIR/vendor/\$ROM_NAME" ]; then
        cp -r "\$ROM_DIR/vendor/\$ROM_NAME" "\$AOSP_DIR/vendor/"
        log_success "Copied vendor overlays"
    fi
    
    # Copy ROM-specific packages
    if [ -d "\$ROM_DIR/packages/apps" ]; then
        for app in \$ROM_DIR/packages/apps/*; do
            if [ -d "\$app" ]; then
                app_name=\$(basename "\$app")
                if [ ! -d "\$AOSP_DIR/packages/apps/\$app_name" ]; then
                    cp -r "\$app" "\$AOSP_DIR/packages/apps/"
                    log_info "Copied ROM app: \$app_name"
                fi
            fi
        done
    fi
    
    # Copy frameworks modifications
    if [ -d "\$ROM_DIR/frameworks/base" ]; then
        log_warning "Framework modifications detected - manual review recommended"
    fi
}

# Apply ROM patches
apply_rom_patches() {
    log_info "Applying \$ROM_NAME patches..."
    
    cd "\$AOSP_DIR"
    
    # Apply any .patch files in the patches directory
    if ls ../patches/\$ROM_NAME/*.patch 1> /dev/null 2>&1; then
        for patch in ../patches/\$ROM_NAME/*.patch; do
            log_info "Applying patch: \$(basename \$patch)"
            git apply "\$patch" || log_warning "Patch \$(basename \$patch) failed to apply"
        done
    fi
    
    cd ..
}

# Update build configuration
update_build_config() {
    log_info "Updating build configuration for \$ROM_NAME..."
    
    # Update build_config.sh with ROM-specific settings
    if [ -f "build_config.sh" ]; then
        sed -i "s/CUSTOM_ROM=\"\"/CUSTOM_ROM=\"\$ROM_NAME\"/" build_config.sh
        log_success "Updated build configuration"
    fi
}

# Main integration process
main() {
    log_info "Starting \$ROM_NAME integration..."
    
    copy_rom_files
    apply_rom_patches
    update_build_config
    
    log_success "\$ROM_NAME integration completed!"
    log_info "You can now build Android with: ./scripts/build_android.sh"
}

main "\$@"
EOF

    chmod +x "$PATCHES_DIR/integrate.sh"
    log_success "Integration script created at $PATCHES_DIR/integrate.sh"
}

# Create device configuration
create_device_config() {
    local rom_name=$1
    local device_codename=${2:-"generic"}
    
    log_info "Creating device configuration for $device_codename..."
    
    DEVICE_CONFIG_DIR="device_configs/$device_codename"
    mkdir -p "$DEVICE_CONFIG_DIR"
    
    # Create device-specific build configuration
    cat > "$DEVICE_CONFIG_DIR/build_config.sh" << EOF
#!/bin/bash

# Device Configuration for $device_codename with $rom_name
# Customize these settings for your specific device

# Device information
DEVICE_CODENAME="$device_codename"
DEVICE_MANUFACTURER="generic"
DEVICE_MODEL="Generic Device"

# Build settings
TARGET_DEVICE="aosp_${device_codename}"
BUILD_VARIANT="userdebug"

# ROM settings
CUSTOM_ROM="$rom_name"

# Device-specific build flags
export TARGET_ARCH="arm64"
export TARGET_ARCH_VARIANT="armv8-a"
export TARGET_CPU_ABI="arm64-v8a"
export TARGET_CPU_ABI2=""
export TARGET_CPU_VARIANT="generic"

# Kernel settings
KERNEL_SOURCE=""
KERNEL_CONFIG=""
KERNEL_CMDLINE=""

# Partition settings
BOARD_BOOTIMAGE_PARTITION_SIZE=""
BOARD_RECOVERYIMAGE_PARTITION_SIZE=""
BOARD_SYSTEMIMAGE_PARTITION_SIZE=""
BOARD_USERDATAIMAGE_PARTITION_SIZE=""

echo "Device configuration loaded for $device_codename with $rom_name"
EOF

    chmod +x "$DEVICE_CONFIG_DIR/build_config.sh"
    log_success "Device configuration created at $DEVICE_CONFIG_DIR/build_config.sh"
}

# Show integration summary
show_integration_summary() {
    local rom_name=$1
    local device_codename=${2:-"generic"}
    
    log_success "Custom ROM integration completed!"
    echo
    log_info "Integration Summary:"
    echo "  ROM: $rom_name"
    echo "  Device: $device_codename"
    echo "  ROM Source: custom_roms/$rom_name"
    echo "  Patches: patches/$rom_name"
    echo "  Device Config: device_configs/$device_codename"
    echo
    log_info "Next steps:"
    echo "1. Review integration patches: patches/$rom_name/integrate.sh"
    echo "2. Customize device configuration: device_configs/$device_codename/build_config.sh"
    echo "3. Run integration: patches/$rom_name/integrate.sh"
    echo "4. Build Android: ./scripts/build_android.sh $device_codename"
    echo
    log_warning "Note: Some ROM features may require manual integration"
    log_warning "Review the ROM documentation for device-specific requirements"
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi
    
    local rom_name=$1
    local device_codename=${2:-"generic"}
    
    log_info "Starting custom ROM integration..."
    log_info "ROM: $rom_name"
    log_info "Device: $device_codename"
    
    check_prerequisites
    download_rom_manifest "$rom_name"
    sync_rom_source "$rom_name"
    create_integration_patches "$rom_name"
    create_device_config "$rom_name" "$device_codename"
    show_integration_summary "$rom_name" "$device_codename"
}

# Run main function
main "$@"
