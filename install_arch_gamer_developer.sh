#!/bin/bash

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

# === CONFIGURABLE VARIABLES ===
DRIVE="/dev/nvme0n1"
HOSTNAME="ArchPredator"
USERNAME="gamerdev"
PASSWORD="coolpat14"
ENCRYPTION_PASS="1ekiglqaPhabi"

# === PACKAGE GROUPS ===
PACKAGES_BASE="base linux linux-firmware intel-ucode"
PACKAGES_DESKTOP="plasma-meta kde-applications sddm konsole dolphin"
PACKAGES_NVIDIA="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
PACKAGES_GAMING="steam lutris wine-staging gamemode lib32-gamemode"
PACKAGES_DEVELOPMENT="git docker docker-compose python python-pip nodejs base-devel"
PACKAGES_ANDROID_AOSP="android-tools android-udev jdk-openjdk"
PACKAGES_AI="python-pytorch python-tensorflow python-jupyter"
PACKAGES_VIRTUALIZATION="qemu-full libvirt virt-manager"
ALL_PACKAGES="$PACKAGES_DESKTOP $PACKAGES_NVIDIA $PACKAGES_GAMING $PACKAGES_DEVELOPMENT $PACKAGES_ANDROID_AOSP $PACKAGES_AI $PACKAGES_VIRTUALIZATION"

echo "⚠️ WARNING: This will irreversibly erase ALL DATA on $DRIVE."
lsblk
read -p "⚠️ Confirm that $DRIVE is correct and you wish to proceed. Press Enter to continue or Ctrl+C to cancel."

# === PREPARE NETWORK + MIRRORS ===
echo "🌐 Setting up fresh mirrors..."
pacman -Sy --noconfirm reflector
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Enable multilib repository
echo "📦 Enabling multilib repository..."
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# === ENABLE NTP ===
timedatectl set-ntp true

# === FULL WIPE AND PARTITIONING ===
echo "🧹 Cleaning previous installations, LUKS headers, and filesystems..."

# Close LUKS if open
cryptsetup close luks_root || true

# Wipe filesystem signatures
wipefs --all --force $DRIVE

# Wipe GPT/MBR
sgdisk --zap-all $DRIVE
sgdisk -Z $DRIVE

# Extra wipe first 10MB to clear leftovers
dd if=/dev/zero of=$DRIVE bs=1M count=10 status=progress

# Reload partition table
partprobe $DRIVE
sleep 2

echo "💽 Creating EFI and BTRFS partitions on $DRIVE..."
sgdisk -n 1:0:+512MiB -t 1:ef00 -c 1:"EFI System" $DRIVE
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux BTRFS" $DRIVE

partprobe $DRIVE
sleep 2

echo "🔍 Verifying partitions:"
lsblk $DRIVE

# Format EFI
mkfs.fat -F32 ${DRIVE}p1

# LUKS encryption setup
echo "🔐 Setting up LUKS encryption on ${DRIVE}p2..."
printf '%s' "$ENCRYPTION_PASS" | cryptsetup luksFormat --type luks2 --batch-mode ${DRIVE}p2
printf '%s' "$ENCRYPTION_PASS" | cryptsetup open ${DRIVE}p2 luks_root

# BTRFS setup
echo "🪵 Creating and mounting BTRFS subvolumes..."
mkfs.btrfs /dev/mapper/luks_root

mount /dev/mapper/luks_root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
umount /mnt

mount -o compress=zstd,noatime,subvol=@ /dev/mapper/luks_root /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots,var/log,var/cache}
mount -o compress=zstd,noatime,subvol=@home /dev/mapper/luks_root /mnt/home
mount -o compress=zstd,noatime,subvol=@.snapshots /dev/mapper/luks_root /mnt/.snapshots
mount -o compress=zstd,noatime,subvol=@var_log /dev/mapper/luks_root /mnt/var/log
mount -o compress=zstd,noatime,subvol=@var_cache /dev/mapper/luks_root /mnt/var/cache
mount ${DRIVE}p1 /mnt/boot/efi

echo "✅ Partitions created, encrypted, formatted, and mounted."

# === BASE INSTALLATION ===
echo "📦 Installing base system..."
pacstrap /mnt $PACKAGES_BASE || { echo "Failed to install base packages"; exit 1; }

echo "📦 Installing desktop environment..."
pacstrap /mnt $PACKAGES_DESKTOP || { echo "Failed to install desktop packages"; exit 1; }

echo "📦 Installing NVIDIA drivers..."
pacstrap /mnt $PACKAGES_NVIDIA || { echo "Failed to install NVIDIA packages"; exit 1; }

echo "📦 Installing gaming packages..."
pacstrap /mnt $PACKAGES_GAMING || { echo "Failed to install gaming packages"; exit 1; }

echo "📦 Installing development tools..."
pacstrap /mnt $PACKAGES_DEVELOPMENT || { echo "Failed to install development packages"; exit 1; }

echo "📦 Installing Android/AOSP tools..."
pacstrap /mnt $PACKAGES_ANDROID_AOSP || { echo "Failed to install Android tools"; exit 1; }

echo "📦 Installing AI/ML packages..."
pacstrap /mnt $PACKAGES_AI || { echo "Failed to install AI packages"; exit 1; }

echo "📦 Installing virtualization packages..."
pacstrap /mnt $PACKAGES_VIRTUALIZATION || { echo "Failed to install virtualization packages"; exit 1; }

# === FSTAB ===
echo "📝 Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# === POSTINSTALL SCRIPT ===
echo "⚙️ Preparing postinstall script..."
cat << EOF > /mnt/root/postinstall.sh
#!/bin/bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
HOSTS

echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel,docker,video,audio,storage,libvirt -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

pacman -Sy --noconfirm grub efibootmgr
UUID=\$(blkid -s UUID -o value ${DRIVE}p2)
sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\\\"cryptdevice=UUID=\$UUID:luks_root root=/dev/mapper/luks_root\\\"|" /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable sddm NetworkManager docker libvirtd tlp

pacman -Sy --noconfirm git base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd ..
rm -rf paru

pacman -Sy --noconfirm snapper
snapper --no-dbus create-config /
systemctl enable snapper-timeline.timer snapper-cleanup.timer

echo "✅ Post-install configuration complete. Reboot to start using your system."
EOF

chmod +x /mnt/root/postinstall.sh

echo "🚪 Entering chroot to execute postinstall script..."
arch-chroot /mnt /root/postinstall.sh

echo "🧹 Cleaning up and unmounting..."
umount -R /mnt
echo "✅ Arch Linux installation complete on your Predator. You may now reboot."