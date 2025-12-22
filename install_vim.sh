#!/usr/bin/env bash

# a1: Install `vim` using the first supported Linux package manager detected on PATH.
set -euo pipefail  # a2: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
    echo "Error: $*" >&2
    exit 1
}

# a3: Fast-path exit when vim is already installed.
if command -v vim >/dev/null 2>&1; then
    echo "Vim is already installed"
    exit 0
fi

# a4: Guardrail: this installer targets Linux package managers only.
if [[ "$(uname -s)" != "Linux" ]]; then
    err "This script targets Linux package managers (apt/dnf/yum/pacman/zypper)."
fi

# a5: Select the first available package manager and install the `vim` package.
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
