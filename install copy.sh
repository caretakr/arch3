#!/bin/sh

#
# Install
#

WORKING_DIRECTORY="$(mktemp -d)"

STORAGE_DEVICE="vda"

ESP_PARTITION="vda1"
BOOT_PARTITION="vda2"
SWAP_PARTITION="vda3"
DATA_PARTITION="vda4"

SWAP_SIZE="3"

_DATA_PASSWORD="1234"

# Stop on error
set -e

_log() {
    # echo "\n##\n## $1\n##\n"
    echo "## $1"
}

_log "Updating system clock..."

timedatectl set-ntp true

if cat /proc/mounts | grep /mnt/boot >/dev/null; then
    _log "Unmounting boot partition..."

    umount /mnt/boot
fi

if cat /proc/mounts | grep /mnt/efi >/dev/null; then
    _log "Unmounting UEFI partition..."

    umount /mnt/efi
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
label-id: 4BF4BE57-EE68-0644-B0BF-A18D039231C7
device: /dev/$STORAGE_DEVICE
unit: sectors
first-lba: 2048
sector-size: 512

/dev/$ESP_PARTITION: start=2048, size=524288, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=C60C9D91-B0A4-8A46-972C-39E2899DBD52
/dev/$BOOT_PARTITION: start=526336, size=1572864, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, uuid=D7594EB7-39A7-6E45-A6E0-4938AEAE28DC
/dev/$SWAP_PARTITION: start=2099200, size=$((($SWAP_SIZE*1024)*2048)), type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=567BD18B-448C-8C4F-AD5B-E4EB94CE745E
/dev/$DATA_PARTITION: start=$(((($SWAP_SIZE*1024)*2048)+2099200)), size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=6A2D732A-0605-5841-A25B-FDB0805B4BE9
EOF

_log "Encrypt data partition..."

echo $_DATA_PASSWORD | cryptsetup luksFormat /dev/$DATA_PARTITION -d -
echo $_DATA_PASSWORD | cryptsetup luksOpen /dev/$DATA_PARTITION \
    $DATA_PARTITION -d -

_log "Format partitions..."

mkfs.fat -F 32 /dev/$ESP_PARTITION
mkfs.btrfs -f /dev/$BOOT_PARTITION
mkswap /dev/$SWAP_PARTITION
mkfs.btrfs -f /dev/mapper/$DATA_PARTITION

_log "Mount partitions..."

mount /dev/$BOOT_PARTITION /mnt

mkdir -p /mnt/boot+SNAPSHOTS
btrfs subvolume create /mnt/boot+LIVE

umount /mnt

mount /dev/mapper/$DATA_PARTITION /mnt

mkdir -p /mnt/home/caretakr+SNAPSHOTS
btrfs subvolume create /mnt/home/caretakr+LIVE
mkdir -p /mnt/root+SNAPSHOTS
btrfs subvolume create /mnt/root+LIVE
mkdir -p /mnt/var/log+SNAPSHOTS
btrfs subvolume create /mnt/var/log+LIVE
mkdir -p /mnt/var/lib/libvirt/images+SNAPSHOTS
btrfs subvolume create /mnt/var/lib/libvirt/images+LIVE

umount /mnt

mount -o noatime,compress=zstd,subvol=root+LIVE /dev/mapper/$DATA_PARTITION \
    /mnt

mkdir -p /mnt/{boot,esp,home/caretakr,var/lib/libvirt/images,var/log}

mount -o noatime,compress=zstd,subvol=boot+LIVE /dev/$BOOT_PARTITION /mnt/boot
mount -o umask=0077 /dev/$ESP_PARTITION /mnt/esp
mount -o noatime,compress=zstd,subvol=home/caretakr+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/home/caretakr
mount -o noatime,compress=zstd,subvol=var/lib/libvirt/images+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/var/lib/libvirt/images
mount -o noatime,nodatacow,compress=zstd,subvol=var/log+LIVE \
    /dev/mapper/$DATA_PARTITION /mnt/var/log

_log "Bootstrapping..."

pacstrap /mnt alsa-utils alsa-plugins base base-devel bluez bluez-utils btrfs-progs dosfstools efibootmgr firewalld git iio-sensor-proxy intel-media-driver intel-ucode linux linux-firmware linux-lts linux-headers pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber

genfstab -U /mnt >> /mnt/etc/fstab

_log "Setting timezone..."

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
arch-chroot /mnt hwclock --systohc

_log "Setting locale..."

arch-chroot /mnt sed -i '/^#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
arch-chroot /mnt locale-gen

_log "Setting language..."

arch-chroot /mnt echo "LANG=en_US.UTF-8" >> /etc/locale.conf
arch-chroot /mnt echo "KEYMAP=br-abnt2" >> /etc/vconsole.conf

_log "Setting hosts..."

arch-chroot /mnt echo "arch" >> /etc/hostname
arch-chroot /mnt echo "127.0.0.1 localhost" >> /etc/hosts
arch-chroot /mnt echo "::1 localhost" >> /etc/hosts
arch-chroot /mnt echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts

_log "Setting user..."

useradd -c Caio -G wheel -m -s /bin/zsh caio

_log "Setting bootloader..."

arch-chroot /mnt cat <<EOF

EOF > /boot/loader.conf

_log "Enable services..."

arch-chroot /mnt systemctl enable fstrim.timer
arch-chroot /mnt systemctl enable bluetooth
arch-chroot /mnt systemctl enable firewalld
