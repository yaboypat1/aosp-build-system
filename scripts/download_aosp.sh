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
log_info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

# Configuration
AOSP_DIR="aosp"
ANDROID_VERSION="android-16.0.0_r1"  # Android 16 release branch
MANIFEST_URL_SSH="ssh://android.googlesource.com/platform/manifest"
MANIFEST_URL_HTTPS="https://android.googlesource.com/platform/manifest"

# Git HTTP tweaks (for HTTPS fallback)
configure_git_http() {
    log_info "Configuring Git HTTP settings for large transfers..."
    git config --global http.postBuffer 524288000
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v repo &> /dev/null; then
        log_error "Repo tool not found. Please run setup_environment.sh first"
        exit 1
    fi
    
    if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then
        log_error "Git not configured. Please run setup_environment.sh first"
        exit 1
    fi
    
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

    # Choose manifest URL: prefer SSH, fallback to HTTPS on timeout
    if ssh -T -p 22 -o ConnectTimeout=5 android.googlesource.com &>/dev/null; then
        MANIFEST_URL="$MANIFEST_URL_SSH"
        log_info "SSH reachable: using SSH manifest URL"
    else
        MANIFEST_URL="$MANIFEST_URL_HTTPS"
        log_warning "SSH port 22 blocked or unreachable; falling back to HTTPS manifest URL"
    fi

    repo init \
        -u "$MANIFEST_URL" \
        -b "$ANDROID_VERSION" \
        --depth=1

    log_success "Repo initialized successfully on branch $ANDROID_VERSION"
}

# Download source code
download_source() {
    log_info "Starting AOSP source download..."
    log_warning "This may take 1–4 hours depending on your connection"
    
    JOBS=$(nproc)
    [ "$JOBS" -gt 8 ] && JOBS=8
    log_info "Using $JOBS parallel jobs for download"

    # attempt up to 5 times, sleeping 20s between failures
    for attempt in {1..5}; do
        if repo sync \
            --force-sync \
            --no-tags \
            --no-clone-bundle \
            --optimized-fetch \
            --prune \
            -j"$JOBS" \
            --fail-fast; then
            log_success "AOSP source download completed on attempt $attempt"
            break
        else
            log_warning "Sync attempt $attempt failed; retrying in 20s..."
            sleep 20
        fi
        if [ "$attempt" -eq 5 ]; then
            log_error "All 5 sync attempts failed. Exiting."
            exit 1
        fi
    done
}

# Verify download
verify_download() {
    log_info "Verifying AOSP download..."
    
    REQUIRED_DIRS=(build frameworks system packages device vendor)
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory '$dir' not found. Download may be incomplete"
            exit 1
        fi
    done
    
    if [ ! -f "build/envsetup.sh" ]; then
        log_error "Build environment setup script not found"
        exit 1
    fi
    
    log_success "AOSP download verification passed"
}

# Setup build environment
setup_build_env() {
    log_info "Setting up build environment..."
    source build/envsetup.sh
    log_info "Available build targets (run 'lunch' to pick one):"
    lunch
    log_success "Build environment ready"
}

# Create a helper build_config.sh
create_build_config() {
    log_info "Creating build configuration..."
    
    cat > ../build_config.sh << 'EOF'
#!/bin/bash
# Android 16 Build Configuration

BUILD_VARIANT="userdebug"
TARGET_DEVICE="aosp_x86_64"
BUILD_JOBS=$(nproc)
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
export USE_NINJA=true
export ALLOW_MISSING_DEPENDENCIES=true
export TARGET_BUILD_APPS=""
export TARGET_BUILD_VARIANT="$BUILD_VARIANT"
CUSTOM_ROM=""
CUSTOM_ROM_BRANCH=""
DEVICE_TREE_PATH=""
VENDOR_TREE_PATH=""
KERNEL_SOURCE_PATH=""

echo "Build configuration loaded:"
echo "  Target: ${TARGET_DEVICE}-${BUILD_VARIANT}"
echo "  Jobs: $BUILD_JOBS"
echo "  ccache: $USE_CCACHE"
EOF
    chmod +x ../build_config.sh
    log_success "build_config.sh created"
}

# Show next steps
show_next_steps() {
    log_success "AOSP source is ready!"
    echo
    log_info "Next steps:"
    echo "1. Review and tweak build_config.sh"
    echo "2. Integrate a custom ROM, e.g.:"
    echo "     ./scripts/integrate_custom_rom.sh lineageos"
    echo "3. Build Android:"
    echo "     ./scripts/build_android.sh"
    echo
    log_info "Source is in: $(pwd)"
    log_info "Total size: $(du -sh . | cut -f1)"
}

# Main
main() {
    log_info "Starting Android 16 AOSP source download..."
    
    configure_git_http
    
    [ ! -d "$AOSP_DIR" ] && { mkdir -p "$AOSP_DIR"; log_info "Created directory: $AOSP_DIR"; }
    
    if [ -f "$AOSP_DIR/build/envsetup.sh" ]; then
        log_warning "AOSP source already exists in $AOSP_DIR"
        read -p "Re‑sync existing tree? (y/N): " -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing source without re-syncing."
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
    cd "$AOSP_DIR"
    setup_build_env
    cd ..
    create_build_config
    show_next_steps
}

main "$@"
