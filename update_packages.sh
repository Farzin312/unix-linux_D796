#!/usr/bin/env bash

# I use strict mode so a failed update stops and the log reflects it.
set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

if [[ "$(uname -s)" != "Linux" ]]; then
    err "This script targets Linux package managers."
fi

LOG_FILE="update.log"
pkg_manager=""

# I detect the package manager first so I can run the right update command.
if command -v apt-get >/dev/null 2>&1; then
    pkg_manager="apt-get"
elif command -v dnf >/dev/null 2>&1; then
    pkg_manager="dnf"
elif command -v yum >/dev/null 2>&1; then
    pkg_manager="yum"
elif command -v pacman >/dev/null 2>&1; then
    pkg_manager="pacman"
elif command -v zypper >/dev/null 2>&1; then
    pkg_manager="zypper"
else
    err "No supported package manager found."
fi

{
    echo "Update started: $(date)"
    case "$pkg_manager" in
        apt-get)
            sudo apt-get update
            sudo apt-get -y upgrade
            ;;
        dnf)
            sudo dnf -y upgrade --refresh
            ;;
        yum)
            sudo yum -y update
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        zypper)
            sudo zypper --non-interactive update
            ;;
        *)
            err "Unsupported package manager: $pkg_manager"
            ;;
    esac
    echo "Update finished: $(date)"
} >"$LOG_FILE" 2>&1

echo "Package update output saved to $LOG_FILE"
