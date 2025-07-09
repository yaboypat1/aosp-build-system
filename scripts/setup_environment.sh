#!/bin/bash

# Android 16 AOSP Build Environment Setup Script
# This script sets up the complete build environment for Android 16 AOSP with custom ROM support

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

# Check if running on supported OS
check_os() {
    log_info "Checking operating system compatibility..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check if it's Ubuntu 18.04 or later
        if command -v lsb_release &> /dev/null; then
            UBUNTU_VERSION=$(lsb_release -rs)
            if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
                log_success "Ubuntu $UBUNTU_VERSION detected - Compatible!"
            else
                log_error "Ubuntu $UBUNTU_VERSION detected - Requires Ubuntu 18.04 or later"
                exit 1
            fi
        else
            log_warning "Cannot determine Ubuntu version, proceeding anyway..."
        fi
    else
        log_error "This script requires Linux. Detected: $OSTYPE"
        exit 1
    fi
}

# Check hardware requirements
check_hardware() {
    log_info "Checking hardware requirements..."
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    log_info "CPU cores: $CPU_CORES"
    if [ "$CPU_CORES" -lt 8 ]; then
        log_warning "Recommended minimum 8 CPU cores for reasonable build times"
    fi
    
    # Check RAM
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Available RAM: ${RAM_GB}GB"
    if [ "$RAM_GB" -lt 32 ]; then
        log_warning "Recommended minimum 32GB RAM. Build may be slow or fail with less RAM"
    fi
    
    # Check disk space
    DISK_SPACE_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    log_info "Available disk space: ${DISK_SPACE_GB}GB"
    if [ "$DISK_SPACE_GB" -lt 400 ]; then
        log_error "Insufficient disk space. Need at least 400GB, have ${DISK_SPACE_GB}GB"
        exit 1
    fi
}

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    # Update package list
    sudo apt-get update
    
    # Install AOSP build dependencies
    sudo apt-get install -y \
        git-core gnupg flex bison build-essential zip curl \
        zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev \
        lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip \
        fontconfig python3 python3-pip bc rsync
    
    # Install additional useful tools
    sudo apt-get install -y \
        vim nano htop tree ccache repo adb fastboot \
        openjdk-11-jdk openjdk-17-jdk
    
    log_success "Required packages installed successfully"
}

# Setup Git configuration
setup_git() {
    log_info "Setting up Git configuration..."
    
    # Check if git is already configured
    if ! git config --global user.name &> /dev/null; then
        read -p "Enter your Git username: " GIT_USERNAME
        git config --global user.name "$GIT_USERNAME"
    fi
    
    if ! git config --global user.email &> /dev/null; then
        read -p "Enter your Git email: " GIT_EMAIL
        git config --global user.email "$GIT_EMAIL"
    fi
    
    # Set up Git for large repositories
    git config --global core.preloadindex true
    git config --global core.fscache true
    git config --global gc.auto 256
    
    log_success "Git configuration completed"
}

# Install and configure Repo tool
setup_repo() {
    log_info "Setting up Repo tool..."
    
    # Create bin directory if it doesn't exist
    mkdir -p ~/bin
    
    # Download repo
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/bin:$PATH"
    fi
    
    log_success "Repo tool installed successfully"
}

# Setup ccache for faster builds
setup_ccache() {
    log_info "Setting up ccache for faster builds..."
    
    # Set ccache size to 100GB
    ccache -M 100G
    
    # Add ccache configuration to bashrc
    if ! grep -q "USE_CCACHE" ~/.bashrc; then
        echo 'export USE_CCACHE=1' >> ~/.bashrc
        echo 'export CCACHE_DIR=~/.ccache' >> ~/.bashrc
    fi
    
    export USE_CCACHE=1
    export CCACHE_DIR=~/.ccache
    
    log_success "ccache configured with 100GB cache size"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    BASE_DIR=$(pwd)
    
    # Create main directories
    mkdir -p aosp
    mkdir -p custom_roms
    mkdir -p device_configs
    mkdir -p patches
    mkdir -p out
    mkdir -p tools
    mkdir -p docs
    
    log_success "Directory structure created"
}

# Setup Java environment
setup_java() {
    log_info "Setting up Java environment..."
    
    # Set JAVA_HOME for OpenJDK 11 (Android 16 requirement)
    JAVA_HOME_PATH="/usr/lib/jvm/java-11-openjdk-amd64"
    
    if [ -d "$JAVA_HOME_PATH" ]; then
        if ! grep -q "JAVA_HOME" ~/.bashrc; then
            echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.bashrc
        fi
        export JAVA_HOME="$JAVA_HOME_PATH"
        log_success "Java 11 environment configured"
    else
        log_warning "Java 11 not found at expected location"
    fi
}

# Main execution
main() {
    log_info "Starting Android 16 AOSP build environment setup..."
    
    check_os
    check_hardware
    install_packages
    setup_git
    setup_repo
    setup_ccache
    create_directories
    setup_java
    
    log_success "Environment setup completed successfully!"
    log_info "Please run 'source ~/.bashrc' or restart your terminal to apply environment changes"
    log_info "Next step: Run './scripts/download_aosp.sh' to download Android 16 source code"
}

# Run main function
main "$@"
