#!/bin/sh

#
# Install
#

set -e

_log() {
    printf "\n▶ $1\n\n"
}

_log "Testing..."

_AAA="1"

. "./test2.sh"