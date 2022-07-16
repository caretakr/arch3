#
# Partition
#

if \
    [ -z $_INSTALL_SCRIPT ] \
    || [ -z $_STORAGE_DEVICE ] \
    || [ -z $_BOOT_PARTITION ] \
    || [ -z $_SWAP_PARTITION ] \
    || [ -z $_SWAP_SIZE ] \
    || [ -z $_DATA_PARTITION ] \
    || [ -z $_DATA_START ] \
    || [ -z $_DATA_PASSWORD ]
then
    echo "Please run using install script: exiting..."; exit
fi

_log "Partitioning device..."

sfdisk "/dev/$_STORAGE_DEVICE" <<EOF
label: gpt
device: /dev/$_STORAGE_DEVICE
unit: sectors
first-lba: 2048
sector-size: 512

/dev/$_BOOT_PARTITION: start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/$_SWAP_PARTITION: start=2099200, size=$_SWAP_SIZE, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/$_DATA_PARTITION: start=$_DATA_START, size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

_log "Encrypting data partition..."

printf $_DATA_PASSWORD | cryptsetup luksFormat /dev/$_DATA_PARTITION -d -

_log "Opening data partition..."

printf $_DATA_PASSWORD | cryptsetup luksOpen /dev/$_DATA_PARTITION \
    $_DATA_PARTITION -d -

_log "Formatting boot partition..."

mkfs.fat -F 32 /dev/$_BOOT_PARTITION

_log "Formatting swap partition..."

mkswap /dev/$_SWAP_PARTITION

_log "Formatting data partition..."

mkfs.btrfs -f /dev/mapper/$_DATA_PARTITION

_log "Mounting data partition..."

mount /dev/mapper/$_DATA_PARTITION /mnt

_log "Creating subvolume for root..."

mkdir -p /mnt/ROOT+SNAPSHOTS
btrfs subvolume create /mnt/ROOT+LIVE

_log "Creating subvolume for user home..."

mkdir -p /mnt/home/caretakr+SNAPSHOTS
btrfs subvolume create /mnt/home/caretakr+LIVE

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
    /dev/mapper/$_DATA_PARTITION /mnt

_log "Creating mount points..."

mkdir -p /mnt/{boot,home/caretakr,root,var/lib/libvirt/images,var/log}

_log "Mounting boot partition..."

mount -o umask=0077 /dev/$_BOOT_PARTITION /mnt/boot

_log "Mounting user home subvolume..."

mount -o noatime,compress=zstd,subvol=home/caretakr+LIVE \
    /dev/mapper/$_DATA_PARTITION /mnt/home/caretakr

_log "Mounting root home subvolume..."

mount -o noatime,compress=zstd,subvol=root+LIVE \
    /dev/mapper/$_DATA_PARTITION /mnt/root

_log "Mounting logs subvolume..."

mount -o noatime,compress=zstd,subvol=var/log+LIVE \
    /dev/mapper/$_DATA_PARTITION /mnt/var/log

_log "Mounting libvirt images subvolume..."
    
mount -o noatime,nodatacow,compress=zstd,subvol=var/lib/libvirt/images+LIVE \
    /dev/mapper/$_DATA_PARTITION /mnt/var/lib/libvirt/images