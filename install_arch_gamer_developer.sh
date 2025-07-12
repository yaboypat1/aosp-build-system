#!/bin/bash

# Define variables
DRIVE="/dev/nvme0n1"  # !! CHANGE THIS TO YOUR TARGET DRIVE !!
HOSTNAME="ArchPredator"
USERNAME="gamerdev"
PASSWORD="your_password" # !! CHANGE THIS TO A SECURE PASSWORD !!
ENCRYPTION_PASS="your_encryption_passphrase" # !! CHANGE THIS TO A SECURE PASSPHRASE !!

# Define the package list (Updated for AI, AOSP, and virtualization)
PACKAGES_BASE="base linux linux-firmware intel-ucode"
PACKAGES_DESKTOP="plasma kde-applications sddm konsole dolphin" # KDE Plasma Desktop
PACKAGES_NVIDIA="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime cuda cudnn" # Added cuda and cudnn for AI
PACKAGES_GAMING="steam lutris wine gamemode mangohud"
PACKAGES_DEVELOPMENT="git docker docker-compose python python-pip nodejs-lts-gallium base-devel" # base-devel is crucial for building software like AOSP
PACKAGES_AI="python-pytorch-cuda python-tensorflow-cuda jupyterlab" # Deep learning libraries (Note: often better installed via Python virtual environments)
PACKAGES_ANDROID_AOSP="android-tools android-udev openjdk-devel git" # Basic Android tools and Java for AOSP
PACKAGES_VIRTUALIZATION="qemu libvirt virt-manager"

# Consolidate all packages for installation
ALL_PACKAGES="$PACKAGES_BASE $PACKAGES_DESKTOP $PACKAGES_NVIDIA $PACKAGES_GAMING $PACKAGES_DEVELOPMENT $PACKAGES_AI $PACKAGES_ANDROID_AOSP $PACKAGES_VIRTUALIZATION"

# --- Installation Steps (Modified Sections) ---

# 1. Update system clock
timedatectl set-ntp true

# 2. Disk Partitioning (Automated BTRFS + LUKS Encryption)
# (Same as previous script - omitted for brevity, handles partitioning and LUKS setup)
echo "Partitioning $DRIVE and setting up LUKS encrypted BTRFS..."

# Clear partition table
sgdisk -Z $DRIVE

# Create EFI partition (512MB)
sgdisk -n 1:0:+512MiB -t 1:ef00 -c 1:"EFI System" $DRIVE

# Create encrypted BTRFS partition (rest of the drive)
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux BTRFS" $DRIVE

# Format EFI partition
mkfs.fat -F 32 ${DRIVE}p1

# Setup LUKS encryption on the main partition
echo -n "$ENCRYPTION_PASS" | cryptsetup luksFormat ${DRIVE}p2 -
echo -n "$ENCRYPTION_PASS" | cryptsetup luksOpen ${DRIVE}p2 luks_root -

# 3. BTRFS Subvolumes and Formatting
# (Same as previous script - handles BTRFS formatting and subvolume mounting)

# Create BTRFS filesystem on the opened encrypted volume
mkfs.btrfs /dev/mapper/luks_root

# Create subvolumes (for BTRFS snapshots)
mount /dev/mapper/luks_root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
umount /mnt

# Mount subvolumes
mount -o compress=zstd,noatime,subvol=@ /dev/mapper/luks_root /mnt
mkdir -p /mnt/{home,.snapshots,var/log,var/cache}
mount -o compress=zstd,noatime,subvol=@home /dev/mapper/luks_root /mnt/home
mount -o compress=zstd,noatime,subvol=@.snapshots /dev/mapper/luks_root /mnt/.snapshots
mount -o compress=zstd,noatime,subvol=@var_log /dev/mapper/luks_root /mnt/var/log
mount -o compress=zstd,noatime,subvol=@var_cache /dev/mapper/luks_root /mnt/var/cache

# Mount EFI partition
mkdir -p /mnt/boot/efi
mount ${DRIVE}p1 /mnt/boot/efi

# 4. Install packages
echo "Installing all packages..."
pacstrap /mnt $ALL_PACKAGES

# 5. Fstab generation
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Chroot into the new system and configure

echo "Entering chroot environment for configuration..."
arch-chroot /mnt /bin/bash <<EOF
# Set timezone, locale, and hostname (Same as previous script)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Root password and user creation (Same as previous script)
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel,docker,video,audio,storage -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# 7. Bootloader installation (GRUB)
pacman -S --noconfirm grub efibootmgr
echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value ${DRIVE}p2):luks_root root=/dev/mapper/luks_root\"" >> /etc/default/grub
# Ensure nvidia_drm.modeset=1 for optimal NVIDIA performance, especially with Wayland/KDE
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 8. Post-installation setup

# Enable essential services
systemctl enable sddm.service
systemctl enable docker.service
systemctl enable NetworkManager.service
systemctl enable libvirtd.service # Enable Libvirt service for virtualization
systemctl enable tlp.service

# Add user to libvirt group for virtualization management
usermod -aG libvirt $USERNAME

# 9. Install AUR helper (yay) and configure Snapper (Same as previous script)
echo "Installing yay (AUR helper)..."
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# Configure Snapper
pacman -S --noconfirm snapper
snapper --no-dbus create-config /
btrfs subvolume snapshot /mnt /mnt/.snapshots/root_snapshot
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# AOSP build dependencies check: We have `base-devel`, `git`, and `openjdk-devel` installed, which are crucial.
# Note: Complex AOSP building often requires specific Python versions and environment variables that are typically configured by the user after installation using `repo` and `envsetup.sh`.

# AI/CUDA setup notes:
# CUDA and cuDNN are installed. Python libraries (PyTorch, TensorFlow) are installed.
# For serious development, users should often use Python virtual environments, but these packages provide system-level availability.

exit
EOF

# 10. Clean up and completion
umount -R /mnt
echo "Arch Linux installation complete. The system is now ready for gaming, development, AI, and complex tasks."
