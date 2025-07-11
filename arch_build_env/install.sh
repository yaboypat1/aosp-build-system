#!/bin/bash

export LC_ALL=C

# Main installer script for the Arch Linux Build Environment

# Color Codes
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# --- Helper Functions ---
info() { echo -e "${C_BLUE}INFO: $1${C_RESET}"; }
success() { echo -e "${C_GREEN}SUCCESS: $1${C_RESET}"; }
error() { echo -e "${C_RED}ERROR: $1${C_RESET}"; exit 1; }
ask() { echo -n -e "${C_YELLOW}INPUT: $1 ${C_RESET}"; }

# --- Pre-flight Checks ---
check_internet() {
    info "Checking for internet connectivity..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection. Please connect to the internet and try again."
    fi
    success "Internet connection is active."
}

# --- Main Script Logic ---

# 1. Welcome and Information Gathering
clear
echo -e "${C_BLUE}====================================================="
echo -e " Welcome to the Arch Linux AOSP Build Environment Setup"
echo -e "====================================================="

check_internet

info "Updating mirrorlist for faster downloads..."
pacman -Sy --noconfirm reflector || error "Failed to install reflector."
# A more robust reflector command with better filtering and verbose output for debugging
reflector --verbose --country 'United States','Canada' --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || error "Reflector failed to run."

# Verify that the mirrorlist is not empty
if [ ! -s /etc/pacman.d/mirrorlist ]; then
    error "Reflector created an empty mirrorlist. Please check your network connection and settings."
fi

success "Mirrorlist updated."

info "This script will install and configure a complete Arch Linux system."
info "Please provide the following information:
"

# Get installation disk
lsblk -d -o NAME,SIZE,MODEL
ask "Enter the disk to install Arch on (e.g., /dev/sda):"
read -r DISK
if [ ! -b "$DISK" ]; then
    error "Disk '$DISK' not found. Please enter a valid block device."
fi

# Get hostname
ask "Enter a hostname for the new system (e.g., arch-dev):"
read -r HOSTNAME
if [ -z "$HOSTNAME" ]; then
    error "Hostname cannot be empty."
fi

# Get username
ask "Enter a username for your user account (e.g., devuser):"
read -r USERNAME
if [ -z "$USERNAME" ]; then
    error "Username cannot be empty."
fi

# Get password
ask "Enter a password for '$USERNAME':"
read -s PASSWORD
echo
ask "Confirm password:"
read -s PASSWORD_CONFIRM
echo
if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ] || [ -z "$PASSWORD" ]; then
    error "Passwords do not match or are empty."
fi

# Confirmation
info "\n--- Installation Details ---"
info "Disk:         $DISK"
info "Hostname:     $HOSTNAME"
info "Username:     $USERNAME"
info "----------------------------"
ask "This will WIPE ALL DATA on $DISK. Continue? (y/N): "
read -r CONFIRM
if [ "$CONFIRM" != "y" ]; then
    error "Installation aborted by user."
fi

# 2. Run Installation Steps

# Make other scripts executable
chmod +x scripts/*.sh

# Partition the disk
info "Starting partitioning..."
./scripts/01-partition.sh "$DISK" || error "Partitioning failed."
success "Disk partitioning complete."

# Install base system
info "Installing base system (this may take a while)..."
./scripts/02-base-install.sh "$DISK" || error "Base system installation failed."
success "Base system installed."

# Copy configuration scripts to new system
info "Copying configuration scripts to /mnt..."
mkdir -p /mnt/arch-setup
cp -r . /mnt/arch-setup || error "Failed to copy scripts."

# Chroot and run configuration
info "Entering chroot to configure the system..."
arch-chroot /mnt /arch-setup/scripts/03-chroot-config.sh "$HOSTNAME" "$USERNAME" "$PASSWORD"
if [ $? -ne 0 ]; then
    error "System configuration inside chroot failed."
fi
success "System configuration complete."

# 3. Finalization
info "Cleaning up..."
rm -rf /mnt/arch-setup
umount -R /mnt

success "Installation is complete!"
echo -e "${C_YELLOW}You can now reboot your system. Remove the installation media first.${C_RESET}"
