#!/bin/bash

export LC_ALL=C

# This script is run inside the chroot environment to configure the new system.

# --- Error Handling & Color Codes ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_RESET='\033[0m'
error() { echo -e "${C_RED}ERROR: $1${C_RESET}"; exit 1; }
info() { echo -e "${C_BLUE}INFO: $1${C_RESET}"; }
success() { echo -e "${C_GREEN}SUCCESS: $1${C_RESET}"; }

# --- Script Arguments ---
HOSTNAME=$1
USERNAME=$2
PASSWORD=$3

# --- System Configuration ---

# 1. Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# 2. Localization
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 3. Network Configuration
echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# 4. Initramfs
mkinitcpio -P

# 5. Bootloader (systemd-boot)
bootctl --path=/boot install || error "systemd-boot installation failed."
cat <<EOF > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
EOF

cat <<EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=root rw
EOF

# 6. Enable essential services
systemctl enable NetworkManager

# 7. Create User and Set Password
useradd -m -g users -G wheel,storage,power -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

# Grant sudo privileges to the wheel group
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# --- Software Installation ---

# 8. Enable Multilib repository
info "Enabling Multilib repository..."

# Add multilib repository
{
    echo ""
    echo "[multilib]"
    echo "Include = /etc/pacman.d/mirrorlist"
} >> /etc/pacman.conf

success "Repository enabled."

# 9. Synchronize package databases and update system
info "Synchronizing package databases..."
pacman -Syyu --noconfirm || error "Failed to synchronize package databases."

# 10. Install core build tools, KDE Plasma, and Applications
info "Installing core build tools, KDE, and all other software..."
pacman -S --noconfirm --needed \
    base-devel \
    intel-ucode amd-ucode \
    plasma-desktop sddm konsole dolphin kate firefox \
    gwenview spectacle okular ark p7zip unrar \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    htop neofetch gparted code \
    || error "Failed to install core software packages."
success "KDE and other packages installed."

# 11. Install Android Build Dependencies
info "Installing Android build dependencies..."
pacman -S --noconfirm --needed \
    jdk11-openjdk git gnupg flex bison gperf \
    zip curl zlib lib32-zlib gcc-multilib \
    lib32-ncurses libx11 lib32-glibc ccache \
    libglvnd libxml2 libxslt unzip schedtool python-setuptools \
    || error "Failed to install Android build dependencies."
success "Android dependencies installed."

# 12. Enable the graphical login manager
systemctl enable sddm

# --- Final Touches ---

# 14. Install AUR helper (paru) and repo tool
info "Installing AUR helper (paru) and repo tool..."
# Run this as the new user
sudo -u $USERNAME /bin/bash <<EOF
cd /home/$USERNAME
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd ..
rm -rf paru
paru -S --noconfirm google-repo
EOF
success "AUR helper and repo installed."

# 15. Configure a default desktop environment
# The user can further customize using the GUI

echo "Chroot configuration complete."