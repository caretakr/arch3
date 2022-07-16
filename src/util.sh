#
# Utilities
#

_log() {
    printf "\n▶ $1\n\n"
}

_download() {
    _log "Cloning repository..."

    git clone -c core.sshCommand="/usr/bin/ssh -i $_SSH_KEY_PATH" \
        git@github.com:caretakr/arch.git $_WORKING_DIRECTORY
}