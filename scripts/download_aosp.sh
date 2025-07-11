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
ANDROID_VERSION="android-16.0.0_r1"
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
    command -v repo &>/dev/null || { log_error "repo not found"; exit 1; }
    git config --global user.name &>/dev/null || { log_error "Git user.name not set"; exit 1; }
    git config --global user.email &>/dev/null || { log_error "Git user.email not set"; exit 1; }
    local space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    (( space >= 250 )) || { log_error "Need ≥250 GB disk; found ${space} GB"; exit 1; }
    log_success "Prerequisites check passed"
}

# Initialize repo
init_repo() {
    log_info "Initializing repo for Android 16..."
    cd "$AOSP_DIR"

    # SSH or HTTPS?
    if ssh -T -p 22 -o ConnectTimeout=5 android.googlesource.com &>/dev/null; then
        MANIFEST_URL="$MANIFEST_URL_SSH"
        log_info "Using SSH manifest URL"
    else
        MANIFEST_URL="$MANIFEST_URL_HTTPS"
        log_warning "SSH blocked; falling back to HTTPS manifest URL"
    fi

    repo init \
        -u "$MANIFEST_URL" \
        -b "$ANDROID_VERSION"
    log_success "Repo initialized on branch $ANDROID_VERSION"
}

# Download the source with retry loop
download_source() {
    log_info "Starting AOSP source download (this may take hours)..."
    local jobs=$(nproc)
    (( jobs > 4 )) && jobs=4
    log_info "Using $jobs parallel jobs"

    for attempt in {1..5}; do
        if repo sync \
            --force-sync \
            --no-tags \
            --optimized-fetch \
            --prune \
            -j"$jobs" \
            --fail-fast; then
            log_success "Download completed on attempt $attempt"
            return
        else
            log_warning "Sync failed (attempt $attempt), retrying in 20 s…"
            sleep 20
        fi
    done

    log_error "All sync attempts failed; aborting"
    exit 1
}

# Verify that key directories exist
verify_download() {
    log_info "Verifying AOSP download…"
    for dir in build frameworks system packages device vendor; do
        [ -d "$dir" ] || { log_error "Missing directory: $dir"; exit 1; }
    done
    [ -f build/envsetup.sh ] || { log_error "Missing build/envsetup.sh"; exit 1; }
    log_success "Verification passed"
}

# Setup build environment
setup_build_env() {
    log_info "Setting up build environment…"
    source build/envsetup.sh
    log_info "Run 'lunch' to select your target"
    lunch
    log_success "Build environment ready"
}

# Create a helper build_config.sh
create_build_config() {
    log_info "Creating build_config.sh…"
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

echo "Loaded config: $TARGET_DEVICE-$BUILD_VARIANT on $BUILD_JOBS jobs"
EOF
    chmod +x ../build_config.sh
    log_success "build_config.sh created"
}

# Show next steps
show_next_steps() {
    log_success "AOSP source is ready!"
    echo
    log_info "Next steps:"
    echo " 1. Review ./build_config.sh"
    echo " 2. Integrate a custom ROM (e.g. ./scripts/integrate_custom_rom.sh lineageos)"
    echo " 3. Build with: ./scripts/build_android.sh"
    echo
    log_info "Source location: $(pwd)"
    log_info "Size: $(du -sh . | cut -f1)"
}

# Main
main() {
    log_info "Android 16 AOSP download starting…"
    configure_git_http

    # Ensure AOSP_DIR exists
    if [ ! -d "$AOSP_DIR" ]; then
        mkdir -p "$AOSP_DIR"
        log_info "Created directory $AOSP_DIR"
    fi

    cd "$AOSP_DIR"
    if [ -f build/envsetup.sh ]; then
        log_warning "Existing source detected"
        read -p "Re-sync? (y/N): " -n1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || { setup_build_env; show_next_steps; exit; }
    fi
    cd ..

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
