#!/bin/bash

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

# === CONFIGURABLE VARIABLES ===
DRIVE="/dev/nvme0n1"
HOSTNAME="ArchPredator"
USERNAME="gamerdev"
PASSWORD="YourSecurePassword"
ENCRYPTION_PASS="YourSecureEncryptionPass"

# === PACKAGE GROUPS ===
PACKAGES_BASE="base linux linux-firmware intel-ucode"
PACKAGES_DESKTOP="plasma kde-applications sddm konsole dolphin"
PACKAGES_NVIDIA="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime cuda cudnn"
PACKAGES_GAMING="steam lutris wine gamemode mangohud"
PACKAGES_DEVELOPMENT="git docker docker-compose python python-pip nodejs-lts base-devel"
PACKAGES_ANDROID_AOSP="android-tools android-udev openjdk"
PACKAGES_AI="python-pytorch-cuda python-tensorflow-cuda jupyterlab"
PACKAGES_VIRTUALIZATION="qemu-full libvirt virt-manager"
ALL_PACKAGES="$PACKAGES_DESKTOP $PACKAGES_NVIDIA $PACKAGES_GAMING $PACKAGES_DEVELOPMENT $PACKAGES_ANDROID_AOSP $PACKAGES_AI $PACKAGES_VIRTUALIZATION"

# === PREPARE NETWORK + MIRRORS ===
echo "🌐 Setting up fresh mirrors..."
pacman -Sy --noconfirm reflector
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# === ENABLE NTP ===
timedatectl set-ntp true

# === PARTITIONING ===
echo "💽 Partitioning $DRIVE..."
sgdisk -Z $DRIVE
sgdisk -n 1:0:+512MiB -t 1:ef00 -c 1:"EFI System" $DRIVE
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux BTRFS" $DRIVE
mkfs.fat -F32 ${DRIVE}p1

echo "$ENCRYPTION_PASS" | cryptsetup luksFormat ${DRIVE}p2 -
echo "$ENCRYPTION_PASS" | cryptsetup luksOpen ${DRIVE}p2 luks_root -
mkfs.btrfs /dev/mapper/luks_root

# === BTRFS SUBVOLUMES ===
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

# === VERIFY MOUNTS ===
mountpoint -q /mnt || { echo "❌ Root not mounted"; exit 1; }
mountpoint -q /mnt/boot/efi || { echo "❌ EFI not mounted"; exit 1; }

# === BASE INSTALLATION ===
echo "📦 Installing base system..."
pacstrap /mnt $PACKAGES_BASE

echo "📦 Installing additional packages..."
pacstrap /mnt $ALL_PACKAGES

# === FSTAB ===
genfstab -U /mnt >> /mnt/etc/fstab

# === POSTINSTALL SCRIPT ===
cat << EOF > /mnt/root/postinstall.sh
#!/bin/bash
set -euo pipefail

# Timezone, locale, hostname
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

# User creation
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel,docker,video,audio,storage,libvirt -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# mkinitcpio hooks
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
pacman -Sy --noconfirm grub efibootmgr
UUID=\$(blkid -s UUID -o value ${DRIVE}p2)
sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\\\"cryptdevice=UUID=\$UUID:luks_root root=/dev/mapper/luks_root\\\"|" /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable sddm NetworkManager docker libvirtd tlp

# AUR Helper
pacman -Sy --noconfirm git base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd ..
rm -rf paru

# Snapper
pacman -Sy --noconfirm snapper
snapper --no-dbus create-config /
systemctl enable snapper-timeline.timer snapper-cleanup.timer

echo "✅ Post-install configuration complete. You can reboot now."
EOF

chmod +x /mnt/root/postinstall.sh

echo "🚪 Chrooting and running postinstall..."
arch-chroot /mnt /root/postinstall.sh

# === CLEANUP ===
umount -R /mnt
echo "✅ Arch Linux installation complete on your Predator. Reboot and enjoy your system!"