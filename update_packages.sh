#!/usr/bin/env bash

# a1: Update OS packages using a detected Linux package manager and log output to a file.
set -euo pipefail  # a2: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
    echo "Error: $*" >&2
    exit 1
}

# a3: Guardrail: this updater targets Linux package managers only.
if [[ "$(uname -s)" != "Linux" ]]; then
    err "This script targets Linux package managers."
fi

# a4: Centralize command output in a single log for auditing and troubleshooting.
LOG_FILE="update.log"
pkg_manager=""

# a5: Detect the first supported package manager available on PATH.
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

# a6: Run the update/upgrade sequence and capture both stdout and stderr in the log file.
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

# a7: Emit the log file path as the final, user-visible output.
echo "Package update output saved to $LOG_FILE"
