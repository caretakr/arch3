#!/bin/sh

#
# Install
#

set -e

_log() {
    printf "\n▶ $1\n\n"
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: exiting..."; exit
fi

_log "Please provide the information below:"

printf "▶ (1/5) Storage device? "; read _STORAGE_DEVICE

if [ ! -b "/dev/$_STORAGE_DEVICE" ]; then
    _log "Storage device not found: exiting..."; exit
fi

printf "▶ (2/5) Data password? "; read -s _DATA_PASSWORD && printf "\n"
printf "▶ (3/5) Data password confirmation? "; read -s _DATA_PASSWORD_CONFIRMATION && printf "\n"

if [ "$_DATA_PASSWORD" != "$_DATA_PASSWORD_CONFIRMATION" ]; then
    _log "Data password mismatch: exiting..."; exit
fi

printf "▶ (4/5) User password? "; read -s _USER_PASSWORD && printf "\n"
printf "▶ (5/5) User password confirmation? "; read -s _USER_PASSWORD_CONFIRMATION && printf "\n"

if [ "$_USER_PASSWORD" != "$_USER_PASSWORD_CONFIRMATION" ]; then
    _log "User password mismatch: exiting..."; exit
fi

BOOT_PARTITION="${_STORAGE_DEVICE}1"
SWAP_PARTITION="${_STORAGE_DEVICE}2"
DATA_PARTITION="${_STORAGE_DEVICE}3"

_SWAP_SIZE=$(($(awk '( $1 == "MemTotal:" ) { printf "%3.0f", ($2/1024)*1.5 }' /proc/meminfo)*2048))
_DATA_START=$(($_SWAP_SIZE+2099200))

_log "Updating system clock..."

timedatectl set-ntp true

_log "Checking previous states..."

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

sfdisk "/dev/$_STORAGE_DEVICE" <<EOF
label: gpt
device: /dev/$_STORAGE_DEVICE
unit: sectors
first-lba: 2048
sector-size: 512

/dev/$BOOT_PARTITION: start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/$SWAP_PARTITION: start=2099200, size=$_SWAP_SIZE, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/$DATA_PARTITION: start=$_DATA_START, size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
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
    bridge-utils \
    brightnessctl \
    bspwm \
    btop \
    btrfs-progs \
    dmidecode \
    dnsmasq \
    docker \
    dosfstools \
    dunst \
    edk2-ovmf \
    efibootmgr \
    feh \
    firefox \
    firefox-developer-edition \
    firewalld \
    flatpak \
    git \
    gnupg \
    gstreamer \
    gstreamer-vaapi \
    gst-libav \
    gst-plugin-pipewire \
    gst-plugins-bad \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-ugly \
    gtk2 \
    gtk3 \
    gtk4 \
    iio-sensor-proxy \
    intel-media-driver \
    intel-ucode \
    iptables-nft \
    kitty \
    libvirt \
    linux \
    linux-firmware \
    linux-headers \
    linux-lts \
    linux-lts-headers \
    mkinitcpio \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    nss-mdns \
    openbsd-netcat \
    openssh \
    picom \
    pinentry \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    playerctl \
    polkit \
    polkit-gnome \
    polybar \
    python \
    qemu-base \
    rofi \
    rustup \
    sof-firmware \
    sxhkd \
    telegram-desktop \
    ttf-font \
    vim \
    virt-manager \
    which \
    wireplumber \
    xdg-desktop-portal-gtk \
    xorg-server \
    xorg-xinit \
    xorg-xinput \
    xorg-xrandr \
    xorg-xset \
    zsh

_log "Setting file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

_log "Setting timezone..."

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
arch-chroot /mnt hwclock --systohc

_log "Setting locale..."

sed -i '/^#en_US.UTF-8 UTF-8/s/^#//g' /mnt/etc/locale.gen
sed -i '/^#pt_BR.UTF-8 UTF-8/s/^#//g' /mnt/etc/locale.gen

arch-chroot /mnt locale-gen

_log "Setting language..."

cat <<EOF > /mnt/etc/locale.conf
LANG=en_US.UTF-8
EOF

_log "Setting console..."

cat <<EOF > /mnt/etc/vconsole.conf
KEYMAP=br-abnt2
EOF

_log "Setting hosts..."

cat <<EOF > /mnt/etc/hostname
arch
EOF

cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 arch.localdomain arch

::1 localhost
EOF

_log "Setting network..."

cat <<EOF > /mnt/etc/systemd/network/20-ethernet.network
[Match]
Name=en*

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=10

[IPv6AcceptRA]
RouteMetric=10
EOF

cat <<EOF > /mnt/etc/systemd/network/25-wireless.network
[Match]
Name=wl*

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=20

[IPv6AcceptRA]
RouteMetric=20
EOF

_log "Setting user..."

arch-chroot /mnt useradd -G docker,kvm,libvirt,wheel -m -s /bin/zsh caretakr
arch-chroot /mnt chown caretakr:caretakr /home/caretakr
arch-chroot /mnt chmod 0700 /home/caretakr

_log "Setting passwords..."

echo "caretakr:$_USER_PASSWORD" | arch-chroot /mnt chpasswd

_log "Setting sudoers..."

cat <<EOF > /mnt/etc/sudoers.d/20-admin
%wheel ALL=(ALL:ALL) ALL
EOF

cat <<EOF > /mnt/etc/sudoers.d/99-install
ALL ALL=(ALL:ALL) NOPASSWD: ALL
EOF

_log "Setting Rust..."

arch-chroot /mnt sudo -u caretakr rustup default stable

_log "Setting Paru..."

arch-chroot /mnt sudo -u caretakr git clone \
    https://aur.archlinux.org/paru.git /var/tmp/paru

arch-chroot /mnt sudo -u caretakr sh -c \
    "(cd /var/tmp/paru && makepkg -si --noconfirm && cd / && rm -rf /var/tmp/paru)"

_log "Setting AUR packages..."

arch-chroot /mnt sudo -u caretakr paru -S --noconfirm \
    android-studio \
    google-chrome \
    nvm \
    plymouth \
    visual-studio-code-bin \
    xbanish

_log "Setting ramdisk..."

sed -i '/^MODULES/s/(.*)/(i915 btrfs)/g' /mnt/etc/mkinitcpio.conf
## sed -i '/^HOOKS/s/(.*)/(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/g' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOKS/s/(.*)/(base udev plymouth autodetect keyboard keymap consolefont modconf block plymouth-encrypt filesystems fsck)/g' /mnt/etc/mkinitcpio.conf

arch-chroot /mnt mkinitcpio -P

_log "Setting bootloader..."

arch-chroot /mnt bootctl install

cat <<EOF > /mnt/boot/loader/loader.conf
default arch
EOF

cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 i915.enable_psr=0 i915.enable_fbc=1
EOF

cat <<EOF > /mnt/boot/loader/entries/arch-fallback.conf
title Arch (fallback)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 i915.enable_psr=0 i915.enable_fbc=1
EOF

cat <<EOF > /mnt/boot/loader/entries/arch-fallback.conf
title Arch (LTS)
linux /vmlinuz-linux
initrd /initramfs-linux-lts.img
options cryptdevice=UUID=$(blkid -s UUID -o value /dev/$DATA_PARTITION):root:allow-discards root=UUID=$(blkid -s UUID -o value /dev/mapper/$DATA_PARTITION) rootflags=subvol=ROOT+LIVE rw quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 i915.enable_psr=0 i915.enable_fbc=1
EOF

_log "Setting clean boot..."

arch-chroot /mnt touch /root/.hushlogin
arch-chroot /mnt touch /home/caretakr/.hushlogin

arch-chroot /mnt setterm -cursor on >> /etc/issue

cat <<EOF > /mnt/etc/sysctl.d/20-quiet.conf
kernel.printk = 3 3 3 3
EOF

_log "Enable services..."

arch-chroot /mnt systemctl enable bluetooth
arch-chroot /mnt systemctl enable docker
arch-chroot /mnt systemctl enable firewalld
arch-chroot /mnt systemctl enable fstrim.timer
arch-chroot /mnt systemctl enable libvirtd

arch-chroot /mnt systemctl enable systemd-networkd
arch-chroot /mnt systemctl enable systemd-resolved

_log "Cleanup..."

rm -f /etc/sudoers.d/99-install
