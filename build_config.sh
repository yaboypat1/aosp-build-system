#!/bin/bash

# Android 16 AOSP Build Configuration
# Main configuration file for build system

# Build Environment Settings
export USE_CCACHE=1
export CCACHE_DIR="${HOME}/.ccache"
export CCACHE_MAXSIZE="100G"

# Java Configuration
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"

# Build Configuration
BUILD_VARIANT="userdebug"  # Options: user, userdebug, eng
TARGET_DEVICE="generic"    # Default device, override with command line
BUILD_JOBS=$(nproc)        # Number of parallel jobs

# Build Options
CLEAN_BUILD=false          # Clean before build
FULL_BUILD=true           # Build all targets
IMAGES_ONLY=false         # Build images only
KERNEL_ONLY=false         # Build kernel only
RECOVERY_ONLY=false       # Build recovery only
OTA_PACKAGE=false         # Build OTA package

# Custom ROM Integration
CUSTOM_ROM=""             # ROM name (lineageos, evolutionx, crdroid, etc.)
ROM_INTEGRATED=false      # Whether ROM has been integrated

# Directory Paths
AOSP_DIR="aosp"
CUSTOM_ROMS_DIR="custom_roms"
OUT_DIR="out"
DEVICE_CONFIGS_DIR="device_configs"
PATCHES_DIR="patches"

# Build Optimization
NINJA_STATUS="[%f/%t] "   # Ninja build status format
USE_NINJA=true            # Use Ninja build system
SOONG_UI_VERBOSE=0        # Soong build verbosity

# Security Settings
ALLOW_MISSING_DEPENDENCIES=false  # Allow missing dependencies
SKIP_API_CHECKS=false            # Skip API compatibility checks
DISABLE_VERITY=false             # Disable dm-verity (for development)

# Signing Configuration
SIGN_BUILDS=false         # Sign builds with custom keys
KEYS_DIR="keys"          # Directory containing signing keys

# Upload/Distribution
UPLOAD_BUILDS=false       # Upload builds after completion
UPLOAD_DESTINATION=""     # Upload destination (FTP, cloud storage, etc.)

# Notification Settings
NOTIFY_ON_COMPLETION=false  # Send notification when build completes
NOTIFICATION_EMAIL=""       # Email for notifications
NOTIFICATION_WEBHOOK=""     # Webhook URL for notifications

# Advanced Build Settings
BOARD_KERNEL_CMDLINE_EXTRAS=""  # Additional kernel command line parameters
TARGET_KERNEL_CONFIG=""         # Custom kernel configuration
BOARD_BOOTIMAGE_PARTITION_SIZE=""  # Boot partition size override

# Performance Tuning
JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
ANDROID_JACK_VM_ARGS="-Xmx4g"

# Development Options
ENABLE_DEBUGGING=false    # Enable additional debugging
VERBOSE_BUILD=false       # Enable verbose build output
SAVE_BUILD_LOG=true      # Save build log to file
BUILD_LOG_FILE="build.log"

# Device-Specific Overrides (loaded from device configs)
DEVICE_SPECIFIC_CONFIG=""

# Function to load device-specific configuration
load_device_config() {
    local device=$1
    local config_file="${DEVICE_CONFIGS_DIR}/${device}/device_config.sh"
    
    if [ -f "$config_file" ]; then
        echo "Loading device configuration for $device..."
        source "$config_file"
        DEVICE_SPECIFIC_CONFIG="$config_file"
        return 0
    else
        echo "Warning: No device configuration found for $device"
        return 1
    fi
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Check required directories
    if [ ! -d "$AOSP_DIR" ]; then
        echo "Error: AOSP directory not found: $AOSP_DIR"
        errors=$((errors + 1))
    fi
    
    # Check Java installation
    if ! command -v java &> /dev/null; then
        echo "Error: Java not found in PATH"
        errors=$((errors + 1))
    fi
    
    # Check ccache if enabled
    if [ "$USE_CCACHE" = "1" ] && ! command -v ccache &> /dev/null; then
        echo "Warning: ccache enabled but not installed"
    fi
    
    # Validate build variant
    case "$BUILD_VARIANT" in
        user|userdebug|eng)
            ;;
        *)
            echo "Error: Invalid build variant: $BUILD_VARIANT"
            errors=$((errors + 1))
            ;;
    esac
    
    # Check disk space (minimum 400GB)
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local min_space=$((400 * 1024 * 1024))  # 400GB in KB
    
    if [ "$available_space" -lt "$min_space" ]; then
        echo "Warning: Low disk space. Minimum 400GB recommended."
    fi
    
    return $errors
}

# Function to show current configuration
show_config() {
    echo "=== Android 16 AOSP Build Configuration ==="
    echo "Build Variant:     $BUILD_VARIANT"
    echo "Target Device:     $TARGET_DEVICE"
    echo "Build Jobs:        $BUILD_JOBS"
    echo "Use ccache:        $USE_CCACHE"
    echo "Custom ROM:        ${CUSTOM_ROM:-None}"
    echo "ROM Integrated:    $ROM_INTEGRATED"
    echo "Clean Build:       $CLEAN_BUILD"
    echo "Full Build:        $FULL_BUILD"
    echo "Java Home:         $JAVA_HOME"
    echo "AOSP Directory:    $AOSP_DIR"
    echo "Output Directory:  $OUT_DIR"
    
    if [ -n "$DEVICE_SPECIFIC_CONFIG" ]; then
        echo "Device Config:     $DEVICE_SPECIFIC_CONFIG"
    fi
    
    echo "=========================================="
}

# Function to setup build environment
setup_build_env() {
    # Set up ccache if enabled
    if [ "$USE_CCACHE" = "1" ]; then
        mkdir -p "$CCACHE_DIR"
        ccache -M "$CCACHE_MAXSIZE" 2>/dev/null || true
    fi
    
    # Create output directory
    mkdir -p "$OUT_DIR"
    
    # Set up build environment variables
    export ANDROID_BUILD_TOP="$(pwd)/$AOSP_DIR"
    export OUT_DIR_COMMON_BASE="$(pwd)/$OUT_DIR"
    
    # Performance optimizations
    export JACK_SERVER_VM_ARGUMENTS="$JACK_SERVER_VM_ARGUMENTS"
    export ANDROID_JACK_VM_ARGS="$ANDROID_JACK_VM_ARGS"
    
    if [ "$USE_NINJA" = "true" ]; then
        export USE_NINJA=1
        export NINJA_STATUS="$NINJA_STATUS"
    fi
    
    # Development options
    if [ "$VERBOSE_BUILD" = "true" ]; then
        export SOONG_UI_VERBOSE=1
    fi
    
    if [ "$ALLOW_MISSING_DEPENDENCIES" = "true" ]; then
        export ALLOW_MISSING_DEPENDENCIES=true
    fi
    
    if [ "$SKIP_API_CHECKS" = "true" ]; then
        export SKIP_API_CHECKS=true
    fi
}

# Function to get build target based on options
get_build_target() {
    if [ "$IMAGES_ONLY" = "true" ]; then
        echo "systemimage"
    elif [ "$KERNEL_ONLY" = "true" ]; then
        echo "bootimage"
    elif [ "$RECOVERY_ONLY" = "true" ]; then
        echo "recoveryimage"
    elif [ "$OTA_PACKAGE" = "true" ]; then
        echo "otapackage"
    else
        echo "bacon"  # Full build target (common in custom ROMs)
    fi
}

# Function to save configuration
save_config() {
    local config_backup="build_config_$(date +%Y%m%d_%H%M%S).sh"
    cp "$0" "$config_backup"
    echo "Configuration saved to: $config_backup"
}

# Auto-load device configuration if TARGET_DEVICE is set
if [ -n "$TARGET_DEVICE" ] && [ "$TARGET_DEVICE" != "generic" ]; then
    load_device_config "$TARGET_DEVICE" 2>/dev/null || true
fi

# Validate configuration on load
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    case "${1:-}" in
        --validate)
            validate_config
            ;;
        --show)
            show_config
            ;;
        --save)
            save_config
            ;;
        *)
            echo "Build configuration loaded successfully"
            echo "Use --validate to check configuration"
            echo "Use --show to display current settings"
            echo "Use --save to backup current configuration"
            ;;
    esac
fi
