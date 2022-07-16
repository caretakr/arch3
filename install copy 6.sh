#!/bin/sh

#
# Install
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: exiting..."; exit
fi

_log() {
    printf "\n▶ $1\n\n"
}

_download() {
    _log "Cloning repository..."

    git clone -c core.sshCommand="/usr/bin/ssh -i $_SSH_KEY_PATH" \
        git@github.com:caretakr/arch.git $_WORKING_DIRECTORY
}

WORKING_DIRECTORY="$(mktemp -d)"
SOURCE_DIRECTORY="$WORKING_DIRECTORY/src"

if [ -d "$SOURCE_DIRECTORY" ] ; then
    for f in "$SOURCE_DIRECTORY"/?*.sh ; do
        . "$f"
    done

    unset f
fi

main() {
    _log "Please provide the following:"

    printf "▶ Storage device? "; read _STORAGE_DEVICE

    if [ ! -b "/dev/$_STORAGE_DEVICE" ]; then
        _log "Storage device not found: exiting..."; exit
    fi

    printf "▶ Data password? "; read -s _DATA_PASSWORD && printf "\n"
    printf "▶ Data password confirmation? "; read -s _DATA_PASSWORD_CONFIRMATION && printf "\n"

    if [ "$_DATA_PASSWORD" != "$_DATA_PASSWORD_CONFIRMATION" ]; then
        _log "Data password mismatch: exiting..."; exit
    fi

    printf "▶ User password? "; read -s _USER_PASSWORD && printf "\n"
    printf "▶ User password confirmation? "; read -s _USER_PASSWORD_CONFIRMATION && printf "\n"

    if [ "$_USER_PASSWORD" != "$_USER_PASSWORD_CONFIRMATION" ]; then
        _log "User password mismatch: exiting..."; exit
    fi

    printf "▶ SSH key path? "; read -s _SSH_KEY_PATH && printf "\n"

    _BOOT_PARTITION="${_STORAGE_DEVICE}1"
    _SWAP_PARTITION="${_STORAGE_DEVICE}2"
    _DATA_PARTITION="${_STORAGE_DEVICE}3"

    _SWAP_SIZE=$(($(awk '( $1 == "MemTotal:" ) { printf "%3.0f", ($2/1024)*1.5 }' /proc/meminfo)*2048))
    _DATA_START=$(($_SWAP_SIZE+2099200))

    _log "Downloading..."

    _download

    _log "Updating system clock..."

    _update_system_clock

    _log "Checking dangling mounts..."

    _check_dangling_mounts

    _log "Checking dangling mappers..."

    _check_dangling_mappers
}

main "$@"