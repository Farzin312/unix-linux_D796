#!/usr/bin/env bash

# I use strict mode so missing commands or failed installs stop immediately.
set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

if command -v vim >/dev/null 2>&1; then
    echo "Vim is already installed"
    exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
    err "This script targets Linux package managers (apt/dnf/yum/pacman/zypper)."
fi

# I pick the first available package manager to install vim.
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y vim
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y vim
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y vim
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm vim
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper --non-interactive install vim
else
    err "No supported package manager found."
fi
