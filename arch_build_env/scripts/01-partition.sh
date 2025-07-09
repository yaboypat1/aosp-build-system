#!/bin/bash

# This script partitions and formats the disk.
# WARNING: This will destroy all data on the specified disk.

# --- Error Handling & Color Codes ---
C_RED='\033[0;31m'
C_RESET='\033[0m'
error() { echo -e "${C_RED}ERROR: $1${C_RESET}"; exit 1; }

# --- Script Logic ---
if [ -z "$1" ]; then
    error "No disk specified. Usage: ./01-partition.sh /dev/sdx"
fi

DISK=$1

# 1. Wipe the disk and create a new GPT partition table
sgdisk --zap-all "$DISK" || error "Failed to zap disk $DISK."
sgdisk --clear "$DISK" || error "Failed to clear partition table on $DISK."

# 2. Create partitions
# Partition 1: EFI System Partition (512M)
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI System Partition" "$DISK" || error "Failed to create EFI partition."

# Partition 2: Swap (16G)
sgdisk --new=2:0:+16G --typecode=2:8200 --change-name=2:"Linux swap" "$DISK" || error "Failed to create swap partition."

# Partition 3: Root (remaining space)
sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:"Linux filesystem" "$DISK" || error "Failed to create root partition."

# 3. Format the partitions
# Use a predictable naming scheme for partitions
if [[ "$DISK" == *"nvme"* ]]; then
    EFI_PART="${DISK}p1"
    SWAP_PART="${DISK}p2"
    ROOT_PART="${DISK}p3"
else
    EFI_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
fi

sleep 2 # Wait for the kernel to recognize the new partitions

mkfs.fat -F32 "$EFI_PART" || error "Failed to format EFI partition."
mkswap "$SWAP_PART" || error "Failed to create swap."
mkfs.ext4 -F "$ROOT_PART" || error "Failed to format root partition."

# 4. Mount the filesystems
mount "$ROOT_PART" /mnt || error "Failed to mount root partition."
mkdir -p /mnt/boot || error "Failed to create /mnt/boot directory."
mount "$EFI_PART" /mnt/boot || error "Failed to mount EFI partition."
swapon "$SWAP_PART" || error "Failed to enable swap."

echo "Disk partitioning and formatting complete."
