#
# Prepare
#

if \
    [ -z $_INSTALL_SCRIPT ] \
    || [ -z $_DATA_PARTITION ]
then
    echo "Please run using install script: exiting..."; exit
fi

_update_system_clock() {
    timedatectl set-ntp true
}

_check_dangling_mounts() {
    if cat /proc/mounts | grep /mnt/boot >/dev/null; then
        _log "Unmounting boot partition..."

        umount /mnt/boot
    fi

    if cat /proc/mounts | grep /mnt/root >/dev/null; then
        _log "Unmounting root home partition..."

        umount /mnt/root
    fi

    if cat /proc/mounts | grep /mnt/home/caretakr >/dev/null; then
        _log "Unmounting user home partition..."

        umount /mnt/home/caretakr
    fi

    if cat /proc/mounts | grep /mnt/var/log >/dev/null; then
        _log "Unmounting log partition..."

        umount /mnt/var/log
    fi

    if cat /proc/mounts | grep /mnt/var/lib/libvirt/images >/dev/null; then
        _log "Unmounting libvirt images partition..."

        umount /mnt/var/lib/libvirt/images
    fi

    if cat /proc/mounts | grep /mnt >/dev/null; then
        _log "Unmounting root partition..."

        umount /mnt
    fi
}

_check_dangling_mappers() {
    if [ -b /dev/mapper/$_DATA_PARTITION ]; then
        _log "Closing encrypted device..."

        cryptsetup close $_DATA_PARTITION
    fi
}

_prepare() {
    _log "Updating system clock..."

    _update_system_clock()

    _log "Checking dangling mounts..."

    _check_dangling_mounts()

    _log "Checking dangling mappers..."

    _check_dangling_mappers()
}
