#!/bin/bash

# This script installs the base Arch Linux system.

# --- Error Handling & Color Codes ---
C_RED='\033[0;31m'
C_RESET='\033[0m'
error() { echo -e "${C_RED}ERROR: $1${C_RESET}"; exit 1; }

# --- Script Logic ---

# 1. Update mirrorlist before installing
# reflector --country 'United States' --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# 2. Install essential packages
pacstrap /mnt base linux linux-firmware base-devel git vim sudo networkmanager || error "Failed to install base packages."

# 3. Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab || error "Failed to generate fstab."

echo "Base system installation complete."
