#!/bin/sh

#
# Install
#

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  
  exit
fi

STORAGE_DEVICE="vda"

BOOT_PARTITION="vda1"
SWAP_PARTITION="vda2"
DATA_PARTITION="vda3"

SWAP_SIZE="3"

_DATA_PASSWORD="1234"
_USER_PASSWORD="1234"

# Stop on error
set -x

_log() {
    set +x; echo "\n▶ $1\n"; set -x
}

_log "Updating system clock..."

timedatectl set-ntp true

if cat /proc/mounts | grep /mnt/boot >/dev/null; then
    _log "Unmounting boot partition..."

    umount /mnt/boot
fi

if cat /proc/mounts | grep /mnt/home/caretakr >/dev/null; then
    _log "Unmounting user home partition..."

    umount /mnt/home/caretakr
fi

if cat /proc/mounts | grep /mnt/root >/dev/null; then
    _log "Unmounting root home partition..."

    umount /mnt/root
fi

if cat /proc/mounts | grep /mnt/var/lib/libvirt/images >/dev/null; then
    _log "Unmounting libvirt images partition..."

    umount /mnt/var/lib/libvirt/images
fi

if cat /proc/mounts | grep /mnt/var/log >/dev/null; then
    _log "Unmounting log partition..."

    umount /mnt/var/log
fi

if cat /proc/mounts | grep /mnt >/dev/null; then
    _log "Unmounting root partition..."

    umount /mnt
fi

if [ -b /dev/mapper/$DATA_PARTITION ]; then
    _log "Closing encrypted device..."

    cryptsetup close $DATA_PARTITION
fi

_log "Partitioning device..."

sfdisk "/dev/$STORAGE_DEVICE" <<EOF
label: gpt
device: /dev/$STORAGE_DEVICE
unit: sectors
first-lba: 2048
sector-size: 512

/dev/$BOOT_PARTITION: start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/$SWAP_PARTITION: start=2099200, size=$((($SWAP_SIZE*1024)*2048)), type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/$DATA_PARTITION: start=$(((($SWAP_SIZE*1024)*2048)+2099200)), size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

_log "Encrypting data partition..."

printf $_DATA_PASSWORD | cryptsetup luksFormat /dev/$DATA_PARTITION -d -

_log "Opening data partition..."

printf $_DATA_PASSWORD | cryptsetup luksOpen /dev/$DATA_PARTITION \
    $DATA_PARTITION -d -

_log "Formatting boot partition..."

mkfs.fat -F 32 /dev/$BOOT_PARTITION

_log "Formatting swap partition..."

mkswap /dev/$SWAP_PARTITION

_log "Formatting data partition..."

mkfs.btrfs -f /dev/mapper/$DATA_PARTITION

_log "Mounting data partition..."

mount /dev/mapper/$DATA_PARTITION /mnt

_log "Creating subvolume for user home..."

mkdir -p /mnt/home/caretakr+SNAPSHOTS
btrfs subvolume create /mnt/home/caretakr+LIVE

_log "Creating subvolume for root..."

mkdir -p /mnt/ROOT+SNAPSHOTS
btrfs subvolume create /mnt/ROOT+LIVE

_log "Creating subvolume for root home..."

mkdir -p /mnt/root+SNAPSHOTS
btrfs subvolume create /mnt/root+LIVE

_log "Creating subvolume for logs..."

mkdir -p /mnt/var/log+SNAPSHOTS
btrfs subvolume create /mnt/var/log+LIVE

_log "Creating subvolume for libvirt images..."

mkdir -p /mnt/var/lib/libvirt/images+SNAPSHOTS
btrfs subvolume create /mnt/var/lib/libvirt/images+LIVE

_log "Unmouting data partition..."

umount /mnt

_log "Mounting root subvolume..."

mount -o noatime,compress=zstd,subvol=ROOT+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt

_log "Creating mount points..."

mkdir -p /mnt/{boot,home/caretakr,root,var/lib/libvirt/images,var/log}

_log "Mounting boot partition..."

mount -o umask=0077 /dev/$BOOT_PARTITION /mnt/boot

_log "Mounting user home subvolume..."

mount -o noatime,compress=zstd,subvol=home/caretakr+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/home/caretakr

_log "Mounting root home subvolume..."

mount -o noatime,compress=zstd,subvol=root+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/root

_log "Mounting libvirt images subvolume..."
    
mount -o noatime,nodatacow,compress=zstd,subvol=var/lib/libvirt/images+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/var/lib/libvirt/images

_log "Mounting logs subvolume..."

mount -o noatime,compress=zstd,subvol=var/log+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/var/log

_log "Bootstrapping..."

pacstrap /mnt \
    alsa-utils \
    alsa-plugins \
    base \
    base-devel \
    bluez \
    bluez-utils \
    btrfs-progs \
    dosfstools \
    efibootmgr \
    firewalld \
    git \
    iio-sensor-proxy \
    intel-media-driver \
    intel-ucode \
    linux \
    linux-firmware \
    linux-headers \
    linux-lts \
    linux-lts-headers \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    vim \
    wireplumber \
    zsh

_log "Generating file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

_log "Setting timezone..."

arch-chroot /mnt sh -c "ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime"
arch-chroot /mnt sh -c "hwclock --systohc"

_log "Setting locale..."

arch-chroot /mnt sh -c "sed -i '/^#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen"
arch-chroot /mnt sh -c "sed -i '/^#pt_BR.UTF-8 UTF-8/s/^#//g' /etc/locale.gen"

arch-chroot /mnt sh -c "locale-gen"

_log "Setting language..."

arch-chroot /mnt sh -c "echo 'LANG=en_US.UTF-8' >> /etc/locale.conf"
arch-chroot /mnt sh -c "echo 'KEYMAP=br-abnt2' >> /etc/vconsole.conf"

_log "Setting hosts..."

arch-chroot /mnt sh -c "echo 'arch' >> /etc/hostname"

arch-chroot /mnt sh -c "echo '127.0.0.1 localhost' >> /etc/hosts"
arch-chroot /mnt sh -c "echo '::1 localhost' >> /etc/hosts"
arch-chroot /mnt sh -c "echo '127.0.1.1 arch.localdomain arch' >> /etc/hosts"

_log "Setting user..."

arch-chroot /mnt sh -c "useradd -c Caio -G wheel -m -s /bin/zsh caio"
arch-chroot /mnt sh -c "echo \"caio:$_USER_PASSWORD\" | chpasswd"

_log "Setting ramdisk..."

arch-chroot /mnt sh -c "sed -i '/^MODULES/s/(.*)/(btrfs)/g' /etc/mkinitcpio.conf"
arch-chroot /mnt sh -c "sed -i '/^HOOKS/s/(.*)/(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/g' /etc/mkinitcpio.conf"
arch-chroot /mnt sh -c "mkinitcpio -P"

_log "Setting bootloader..."

arch-chroot /mnt sh -c "bootctl install"

arch-chroot /mnt sh -c "echo 'default arch' >> /boot/loader/loader.conf"

arch-chroot /mnt sh -c "echo 'title Arch' >> /boot/loader/entries/arch.conf"
arch-chroot /mnt sh -c "echo 'linux /vmlinuz-linux' >> /boot/loader/entries/arch.conf"
arch-chroot /mnt sh -c "echo 'initrd /initramfs-linux.img' >> /boot/loader/entries/arch.conf"
arch-chroot /mnt sh -c "echo 'options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw i915.enable_psr=0 i915.enable_fbc=1' >> /boot/loader/entries/arch.conf"

arch-chroot /mnt sh -c "echo 'title Arch (fallback)' >> /boot/loader/entries/arch-fallback.conf"
arch-chroot /mnt sh -c "echo 'linux /vmlinuz-linux' >> /boot/loader/entries/arch-fallback.conf"
arch-chroot /mnt sh -c "echo 'initrd /initramfs-linux-fallback.img' >> /boot/loader/entries/arch-fallback.conf"
arch-chroot /mnt sh -c "echo 'options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw i915.enable_psr=0 i915.enable_fbc=1' >> /boot/loader/entries/arch-fallback.conf"

arch-chroot /mnt sh -c "echo 'title Arch (LTS)' >> /boot/loader/entries/arch-lts.conf"
arch-chroot /mnt sh -c "echo 'linux /vmlinuz-linux' >> /boot/loader/entries/arch-lts.conf"
arch-chroot /mnt sh -c "echo 'initrd /initramfs-linux-lts.img' >> /boot/loader/entries/arch-lts.conf"
arch-chroot /mnt sh -c "echo 'options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw i915.enable_psr=0 i915.enable_fbc=1' >> /boot/loader/entries/arch-lts.conf"

_log "Enable services..."

arch-chroot /mnt systemctl enable fstrim.timer
arch-chroot /mnt systemctl enable bluetooth
arch-chroot /mnt systemctl enable firewalld
