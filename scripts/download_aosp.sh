#!/bin/bash

# Android 16 AOSP Source Download Script
# Downloads the complete Android 16 AOSP source code

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

# Configuration
AOSP_DIR="aosp"
ANDROID_VERSION="android-16.0.0_r1"  # Android 16 release branch
MANIFEST_URL="https://android.googlesource.com/platform/manifest"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if repo is installed
    if ! command -v repo &> /dev/null; then
        log_error "Repo tool not found. Please run setup_environment.sh first"
        exit 1
    fi
    
    # Check if git is configured
    if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then
        log_error "Git not configured. Please run setup_environment.sh first"
        exit 1
    fi
    
    # Check disk space (need at least 250GB for source)
    DISK_SPACE_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$DISK_SPACE_GB" -lt 250 ]; then
        log_error "Insufficient disk space. Need at least 250GB for AOSP source, have ${DISK_SPACE_GB}GB"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize repo
init_repo() {
    log_info "Initializing repo for Android 16..."
    
    cd "$AOSP_DIR"
    
    # Initialize repo with Android 16 manifest
    # Using android-latest-release as recommended by Google starting March 27, 2025
    log_info "Using android-latest-release branch (recommended for Android 16)"
    repo init -u "$MANIFEST_URL" -b android-latest-release --depth=1
    
    log_success "Repo initialized successfully"
}

# Download source code
download_source() {
    log_info "Starting AOSP source download..."
    log_warning "This will take a long time (1-4 hours depending on your internet connection)"
    
    # Show progress and use multiple jobs for faster download
    JOBS=$(nproc)
    if [ "$JOBS" -gt 8 ]; then
        JOBS=8  # Limit to 8 jobs to avoid overwhelming the server
    fi
    
    log_info "Using $JOBS parallel jobs for download"
    
    # Sync with progress and resume capability
    repo sync -c -j"$JOBS" --force-sync --no-tags --no-clone-bundle --optimized-fetch --prune
    
    log_success "AOSP source download completed"
}

# Verify download
verify_download() {
    log_info "Verifying AOSP download..."
    
    # Check if key directories exist
    REQUIRED_DIRS=("build" "frameworks" "system" "packages" "device" "vendor")
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory '$dir' not found. Download may be incomplete"
            exit 1
        fi
    done
    
    # Check build system
    if [ ! -f "build/envsetup.sh" ]; then
        log_error "Build environment setup script not found"
        exit 1
    fi
    
    log_success "AOSP download verification passed"
}

# Setup build environment
setup_build_env() {
    log_info "Setting up build environment..."
    
    # Source the build environment
    source build/envsetup.sh
    
    # Show available targets
    log_info "Available build targets:"
    lunch
    
    log_success "Build environment ready"
}

# Create build configuration
create_build_config() {
    log_info "Creating build configuration..."
    
    # Create a default build configuration file
    cat > ../build_config.sh << 'EOF'
#!/bin/bash

# Android 16 Build Configuration
# Modify these settings according to your needs

# Build variant (eng, userdebug, user)
BUILD_VARIANT="userdebug"

# Target device (aosp_x86_64, aosp_arm64, etc.)
TARGET_DEVICE="aosp_x86_64"

# Number of parallel jobs (adjust based on your CPU cores and RAM)
BUILD_JOBS=$(nproc)

# Enable ccache for faster builds
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache

# Build with ninja (faster build system)
export USE_NINJA=true

# Additional build flags
export ALLOW_MISSING_DEPENDENCIES=true
export TARGET_BUILD_APPS=""
export TARGET_BUILD_VARIANT="$BUILD_VARIANT"

# Custom ROM integration settings
CUSTOM_ROM=""
CUSTOM_ROM_BRANCH=""

# Device specific settings
DEVICE_TREE_PATH=""
VENDOR_TREE_PATH=""
KERNEL_SOURCE_PATH=""

echo "Build configuration loaded:"
echo "  Target: ${TARGET_DEVICE}-${BUILD_VARIANT}"
echo "  Jobs: $BUILD_JOBS"
echo "  ccache: $USE_CCACHE"
EOF

    chmod +x ../build_config.sh
    log_success "Build configuration created at build_config.sh"
}

# Show next steps
show_next_steps() {
    log_success "AOSP download completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review and modify build_config.sh if needed"
    echo "2. Choose a custom ROM to integrate:"
    echo "   ./scripts/integrate_custom_rom.sh lineageos"
    echo "   ./scripts/integrate_custom_rom.sh evolution-x"
    echo "   ./scripts/integrate_custom_rom.sh crdroid"
    echo "3. Build Android:"
    echo "   ./scripts/build_android.sh"
    echo
    log_info "AOSP source location: $(pwd)/$AOSP_DIR"
    log_info "Total source size: $(du -sh $AOSP_DIR | cut -f1)"
}

# Main execution
main() {
    log_info "Starting Android 16 AOSP source download..."
    
    # Create AOSP directory if it doesn't exist
    if [ ! -d "$AOSP_DIR" ]; then
        mkdir -p "$AOSP_DIR"
        log_info "Created AOSP directory: $AOSP_DIR"
    fi
    
    # Check if AOSP is already downloaded
    if [ -f "$AOSP_DIR/build/envsetup.sh" ]; then
        log_warning "AOSP source appears to already exist"
        read -p "Do you want to update/re-sync? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping download. Using existing AOSP source."
            cd "$AOSP_DIR"
            setup_build_env
            cd ..
            show_next_steps
            exit 0
        fi
    fi
    
    check_prerequisites
    init_repo
    download_source
    verify_download
    setup_build_env
    cd ..
    create_build_config
    show_next_steps
}

# Run main function
main "$@"
