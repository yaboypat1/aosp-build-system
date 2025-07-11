#!/bin/bash

# Android 16 AOSP Build Script
# Builds Android 16 with optional custom ROM integration

set -e
export LC_ALL=C

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Default configuration
DEFAULT_TARGET="aosp_x86_64"
DEFAULT_VARIANT="userdebug"
BUILD_START_TIME=$(date +%s)

# Usage function
usage() {
    echo "Usage: $0 [device_codename] [build_variant] [options]"
    echo
    echo "Parameters:"
    echo "  device_codename  Target device (default: x86_64)"
    echo "  build_variant    Build variant: eng, userdebug, user (default: userdebug)"
    echo
    echo "Options:"
    echo "  -j, --jobs N     Number of parallel jobs (default: auto-detect)"
    echo "  -c, --clean      Clean build (removes previous build artifacts)"
    echo "  -f, --full       Full build (equivalent to 'make')"
    echo "  -i, --images     Build system images only"
    echo "  -k, --kernel     Build kernel only"
    echo "  -r, --recovery   Build recovery image"
    echo "  -o, --ota        Build OTA package"
    echo "  --ccache         Force enable ccache"
    echo "  --no-ccache      Disable ccache"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                           # Build aosp_x86_64-userdebug"
    echo "  $0 komodo user               # Build aosp_komodo-user"
    echo "  $0 generic eng --clean      # Clean build of aosp_generic-eng"
    echo "  $0 --images                 # Build system images only"
}

# Parse command line arguments
parse_arguments() {
    DEVICE_CODENAME=""
    BUILD_VARIANT=""
    BUILD_JOBS=""
    CLEAN_BUILD=false
    FULL_BUILD=false
    IMAGES_ONLY=false
    KERNEL_ONLY=false
    RECOVERY_ONLY=false
    OTA_PACKAGE=false
    FORCE_CCACHE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--jobs)
                BUILD_JOBS="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -f|--full)
                FULL_BUILD=true
                shift
                ;;
            -i|--images)
                IMAGES_ONLY=true
                shift
                ;;
            -k|--kernel)
                KERNEL_ONLY=true
                shift
                ;;
            -r|--recovery)
                RECOVERY_ONLY=true
                shift
                ;;
            -o|--ota)
                OTA_PACKAGE=true
                shift
                ;;
            --ccache)
                FORCE_CCACHE="1"
                shift
                ;;
            --no-ccache)
                FORCE_CCACHE="0"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [ -z "$DEVICE_CODENAME" ]; then
                    DEVICE_CODENAME="$1"
                elif [ -z "$BUILD_VARIANT" ]; then
                    BUILD_VARIANT="$1"
                else
                    log_error "Too many arguments: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Set defaults
    DEVICE_CODENAME=${DEVICE_CODENAME:-"x86_64"}
    BUILD_VARIANT=${BUILD_VARIANT:-"userdebug"}
    BUILD_JOBS=${BUILD_JOBS:-$(nproc)}
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking build prerequisites..."

    if [ ! -d "aosp" ] || [ ! -f "aosp/build/envsetup.sh" ]; then
        log_error "AOSP source not found. Please run download_aosp.sh first"
        exit 1
    fi

    DISK_SPACE_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$DISK_SPACE_GB" -lt 150 ]; then
        log_error "Insufficient disk space. Need at least 150GB for build, have ${DISK_SPACE_GB}GB"
        exit 1
    fi

    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$RAM_GB" -lt 16 ]; then
        log_warning "Low RAM detected (${RAM_GB}GB). Build may be slow or fail"
        log_warning "Consider reducing parallel jobs or adding swap space"
    fi

    log_success "Prerequisites check passed"
}

# Load build configuration
load_build_config() {
    log_info "Loading build configuration..."

    if [ -f "build_config.sh" ]; then
        source build_config.sh
        log_info "Loaded main build configuration"
    fi

    # Check for device manufacturer to construct path
    # This allows for device_configs/google/komodo, device_configs/oneplus/op9, etc.
    DEVICE_MANUFACTURER=$(grep -oP 'DEVICE_MANUFACTURER="\K[^"]+' "device_configs/google/${DEVICE_CODENAME}/build_config.sh" 2>/dev/null || echo "generic")
    DEVICE_CONFIG="device_configs/${DEVICE_MANUFACTURER}/${DEVICE_CODENAME}/build_config.sh"

    if [ -f "$DEVICE_CONFIG" ]; then
        source "$DEVICE_CONFIG"
        log_info "Loaded device configuration for $DEVICE_CODENAME"
    fi

    if [ -n "$FORCE_CCACHE" ]; then
        export USE_CCACHE="$FORCE_CCACHE"
    fi

    BUILD_TARGET="aosp_${DEVICE_CODENAME}-${BUILD_VARIANT}"

    log_info "Build configuration:"
    log_info "  Target: $BUILD_TARGET"
    log_info "  Jobs: $BUILD_JOBS"
    log_info "  ccache: ${USE_CCACHE:-0}"
    log_info "  Clean build: $CLEAN_BUILD"
}

# Setup build environment
setup_build_environment() {
    log_info "Setting up build environment..."
    cd aosp

    source build/envsetup.sh

    log_info "Selecting build target: $BUILD_TARGET"
    lunch "$BUILD_TARGET"

    if [ "${USE_CCACHE}" = "1" ]; then
        log_info "ccache enabled with directory: ${CCACHE_DIR:-~/.ccache}"
        export USE_CCACHE=1
        export CCACHE_DIR=${CCACHE_DIR:-~/.ccache}
        
        if command -v ccache &> /dev/null; then
            log_info "ccache status:"
            ccache -s | head -5
        fi
    fi

    log_success "Build environment ready"
}

# Clean build artifacts
clean_build() {
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Cleaning previous build artifacts..."
        if [ -d "out" ]; then
            rm -rf out
            log_info "Removed out/ directory"
        fi

        if [ "${USE_CCACHE}" = "1" ] && command -v ccache &> /dev/null; then
            read -p "Clean ccache as well? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ccache -C
                log_info "ccache cleared"
            fi
        fi
        
        log_success "Build artifacts cleaned"
    fi
}

# Build Android
build_android() {
    log_info "Starting Android build..."
    log_info "Build target: $BUILD_TARGET"
    log_info "Parallel jobs: $BUILD_JOBS"

    BUILD_COMMAND="m"
    BUILD_TARGETS=""

    if [ "$KERNEL_ONLY" = true ]; then
        BUILD_TARGETS="bootimage"
        log_info "Building kernel and boot image only"
    elif [ "$RECOVERY_ONLY" = true ]; then
        BUILD_TARGETS="recoveryimage"
        log_info "Building recovery image only"
    elif [ "$IMAGES_ONLY" = true ]; then
        BUILD_TARGETS="systemimage vendorimage bootimage"
        log_info "Building system images only"
    elif [ "$OTA_PACKAGE" = true ]; then
        BUILD_TARGETS="otapackage"
        log_info "Building OTA package"
    elif [ "$FULL_BUILD" = true ]; then
        BUILD_COMMAND="make"
        log_info "Full build (make)"
    else
        log_info "Building Android (default targets)"
    fi

    if [ -n "$BUILD_TARGETS" ]; then
        $BUILD_COMMAND -j"$BUILD_JOBS" $BUILD_TARGETS
    else
        $BUILD_COMMAND -j"$BUILD_JOBS"
    fi

    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        log_success "Android build completed successfully!"
    else
        log_error "Build failed with exit code $BUILD_EXIT_CODE"
        exit $BUILD_EXIT_CODE
    fi
}

# Show build results
show_build_results() {
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    BUILD_HOURS=$((BUILD_DURATION / 3600))
    BUILD_MINUTES=$(((BUILD_DURATION % 3600) / 60))
    BUILD_SECONDS=$((BUILD_DURATION % 60))

    log_success "Build completed successfully!"
    echo
    log_info "Build Summary:"
    echo "  Target: $BUILD_TARGET"
    echo "  Duration: ${BUILD_HOURS}h ${BUILD_MINUTES}m ${BUILD_SECONDS}s"
    echo "  Jobs: $BUILD_JOBS"
    echo "  ccache: ${USE_CCACHE:-0}"
    echo

    if [ -d "out/target/product/$DEVICE_CODENAME" ]; then
        OUTPUT_DIR="out/target/product/$DEVICE_CODENAME"
        log_info "Build artifacts location: $OUTPUT_DIR"
        
        echo "Key files generated:"
        if [ -f "$OUTPUT_DIR/system.img" ]; then
            echo "  - system.img ($(du -h $OUTPUT_DIR/system.img | cut -f1))"
        fi
        if [ -f "$OUTPUT_DIR/boot.img" ]; then
            echo "  - boot.img ($(du -h $OUTPUT_DIR/boot.img | cut -f1))"
        fi
        if [ -f "$OUTPUT_DIR/recovery.img" ]; then
            echo "  - recovery.img ($(du -h $OUTPUT_DIR/recovery.img | cut -f1))"
        fi
        if [ -f "$OUTPUT_DIR"/*-ota-*.zip ]; then
            echo "  - OTA package: $(ls $OUTPUT_DIR/*-ota-*.zip | head -1 | xargs basename)"
        fi
        if [ -f "$OUTPUT_DIR"/*-img-*.zip ]; then
            echo "  - Fastboot images: $(ls $OUTPUT_DIR/*-img-*.zip | head -1 | xargs basename)"
        fi

        echo
        log_info "Total build output size: $(du -sh $OUTPUT_DIR | cut -f1)"
    fi

    if [ "${USE_CCACHE}" = "1" ] && command -v ccache &> /dev/null; then
        echo
        log_info "ccache statistics:"
        ccache -s | head -10
    fi

    echo
    log_info "Next steps:"
    echo "1. Flash images to device using fastboot"
    echo "2. Test in emulator: emulator -avd <avd_name>"
    echo "3. Create OTA package: ./scripts/build_android.sh --ota"
}

# Main execution
main() {
    log_info "Starting Android 16 AOSP build process..."

    parse_arguments "$@"
    check_prerequisites
    load_build_config
    setup_build_environment
    clean_build
    build_android
    show_build_results
    
    cd ..
}

# Run main function
main "$@"
