#!/bin/bash

# === CONFIGURATION ===
TARGET_DISK="/dev/nvme0n1"  # Change this to match your disk
SWAP_SIZE="16G"            # Swap size (adjust as needed)
HOSTNAME="archgaming"      # Your hostname
USERNAME="pat"             # Your username
PASSWORD="coolpat14"    # Your password (change this!)
ROOT_PASSWORD="coolpat14"  # Root password (change this!)

# === PACKAGE GROUPS ===
PACKAGES_BASE="base base-devel linux linux-firmware intel-ucode sudo"

PACKAGES_DESKTOP="plasma-desktop plasma-wayland-protocols plasma-workspace sddm konsole dolphin plasma-pa plasma-nm powerdevil kscreen plasma-systemmonitor kde-gtk-config breeze-gtk xdg-desktop-portal-kde packagekit-qt5 kwallet-pam ksshaskpass kwalletmanager"

PACKAGES_NVIDIA="nvidia nvidia-utils nvidia-settings"

PACKAGES_GAMING="steam lutris wine wine-gecko wine-mono gamemode discord"

PACKAGES_DEVELOPMENT="git docker docker-compose python python-pip nodejs npm cmake gcc gdb make"

PACKAGES_ANDROID_AOSP="android-tools android-udev jdk17-openjdk repo"

PACKAGES_AI="python-pytorch python-tensorflow jupyter-notebook python-pip python-scikit-learn python-pandas python-numpy"

PACKAGES_VIRTUALIZATION="qemu-full virt-manager libvirt edk2-ovmf dnsmasq bridge-utils"

PACKAGES_UTILITIES="firefox wget curl htop spectacle ark unzip p7zip-full kate networkmanager bluez bluez-utils"

# Combine all packages
ALL_PACKAGES="$PACKAGES_BASE $PACKAGES_DESKTOP $PACKAGES_NVIDIA $PACKAGES_GAMING $PACKAGES_DEVELOPMENT $PACKAGES_ANDROID_AOSP $PACKAGES_AI $PACKAGES_VIRTUALIZATION $PACKAGES_UTILITIES"

# === PREPARE NETWORK + MIRRORS ===
echo "🌐 Setting up fresh mirrors..."
pacman -Sy --noconfirm reflector
echo "📡 Finding fastest mirrors..."
reflector --latest 20 \
    --protocol https \
    --sort rate \
    --country 'United States' \
    --fastest 10 \
    --age 12 \
    --save /etc/pacman.d/mirrorlist

# Enable multilib repository
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Syy  # Refresh package databases

# === DISK PARTITIONING ===
echo "💽 Partitioning disk..."
# Create GPT partition table
parted -s $TARGET_DISK mklabel gpt

# Create EFI partition (550MB)
parted -s $TARGET_DISK mkpart primary fat32 1MiB 551MiB
parted -s $TARGET_DISK set 1 esp on

# Create swap partition
parted -s $TARGET_DISK mkpart primary linux-swap 551MiB ${SWAP_SIZE}B

# Create root partition (rest of disk)
parted -s $TARGET_DISK mkpart primary btrfs ${SWAP_SIZE}B 100%

# Format partitions
echo "📝 Formatting partitions..."
mkfs.fat -F32 "${TARGET_DISK}p1"
mkswap "${TARGET_DISK}p2"
mkfs.btrfs -f "${TARGET_DISK}p3"

# Mount root partition
mount "${TARGET_DISK}p3" /mnt
cd /mnt

# Create btrfs subvolumes
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @var
btrfs subvolume create @opt
btrfs subvolume create @tmp
cd

# Mount subvolumes
umount /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "${TARGET_DISK}p3" /mnt
mkdir -p /mnt/{boot,home,var,opt,tmp}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "${TARGET_DISK}p3" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var "${TARGET_DISK}p3" /mnt/var
mount -o noatime,compress=zstd,space_cache=v2,subvol=@opt "${TARGET_DISK}p3" /mnt/opt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@tmp "${TARGET_DISK}p3" /mnt/tmp

# Mount EFI partition
mount "${TARGET_DISK}p1" /mnt/boot

# Enable swap
swapon "${TARGET_DISK}p2"

# Function to retry package installation
install_packages() {
    local packages="$1"
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "📦 Installation attempt $attempt of $max_attempts..."
        if pacstrap /mnt $packages; then
            return 0
        fi
        echo "⚠️ Attempt $attempt failed. Refreshing mirrors..."
        arch-chroot /mnt pacman -Syy
        ((attempt++))
        sleep 10
    done
    return 1
}

# === BASE INSTALLATION ===
echo "📦 Installing base system..."
install_packages "$PACKAGES_BASE" || { echo "Failed to install base packages"; exit 1; }

# Enable multilib in the installed system
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Syy

# Install 32-bit NVIDIA libraries
arch-chroot /mnt pacman -S --noconfirm lib32-nvidia-utils

echo "📦 Installing desktop environment..."
install_packages "$PACKAGES_DESKTOP" || { echo "Failed to install desktop packages"; exit 1; }

echo "📦 Installing NVIDIA drivers..."
install_packages "$PACKAGES_NVIDIA" || { echo "Failed to install NVIDIA packages"; exit 1; }

echo "📦 Installing gaming packages..."
install_packages "$PACKAGES_GAMING" || { echo "Failed to install gaming packages"; exit 1; }

echo "📦 Installing development tools..."
install_packages "$PACKAGES_DEVELOPMENT" || { echo "Failed to install development packages"; exit 1; }

echo "📦 Installing Android/AOSP tools..."
install_packages "$PACKAGES_ANDROID_AOSP" || { echo "Failed to install Android tools"; exit 1; }

echo "📦 Installing AI/ML packages..."
install_packages "$PACKAGES_AI" || { echo "Failed to install AI packages"; exit 1; }

echo "📦 Installing virtualization packages..."
install_packages "$PACKAGES_VIRTUALIZATION" || { echo "Failed to install virtualization packages"; exit 1; }

echo "📦 Installing utility packages..."
install_packages "$PACKAGES_UTILITIES" || { echo "Failed to install utility packages"; exit 1; }

# === SYSTEM CONFIGURATION ===
echo "⚙️ Configuring system..."

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Set timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Set hostname
echo $HOSTNAME > /mnt/etc/hostname

# Configure hosts file
cat > /mnt/etc/hosts << EOF
127.0.0.1     localhost
::1           localhost
127.0.1.1     $HOSTNAME.localdomain     $HOSTNAME
EOF

# Set root password
echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd

# Create user
arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,docker -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | arch-chroot /mnt chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" > /mnt/etc/sudoers.d/wheel

# Configure mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems keyboard fsck)/' /mnt/etc/mkinitcpio.conf
sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

# Install and configure bootloader
arch-chroot /mnt bootctl install
cat > /mnt/boot/loader/loader.conf << EOF
default arch.conf
timeout 4
console-mode max
editor no
EOF

cat > /mnt/boot/loader/entries/arch.conf << EOF
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value "${TARGET_DISK}p3") rootflags=subvol=@ rw nvidia-drm.modeset=1
EOF

# Enable services
arch-chroot /mnt systemctl enable sddm NetworkManager docker libvirtd bluetooth

# Configure NVIDIA early loading
echo "options nvidia-drm modeset=1" > /mnt/etc/modprobe.d/nvidia.conf

# Enable Docker socket
arch-chroot /mnt systemctl enable docker.socket

# Enable Bluetooth
arch-chroot /mnt systemctl enable bluetooth

# Enable TRIM for SSDs
arch-chroot /mnt systemctl enable fstrim.timer

echo "✅ Installation complete! You can now reboot."