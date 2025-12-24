#!/usr/bin/env bash
# update_packages.sh — WGU D796 RQN1 Task 1 (D2)
# Updates installed packages and saves output to update.log

set -euo pipefail

err() { echo "Error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || err "This script targets Linux package managers."

LOG_FILE="update.log"

# Detect package manager
pkg_manager=""
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

# Ask for sudo ONCE up front so it doesn't "hang" invisibly later
echo "Requesting sudo privileges..."
sudo -v || err "sudo authentication failed"

# For apt: wait for locks a bit (common on Ubuntu)
wait_for_apt_locks() {
  local tries=30
  local i=0
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
     || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    i=$((i+1))
    if (( i > tries )); then
      err "apt/dpkg lock still held after waiting. Another update process may be running."
    fi
    echo "Waiting for apt/dpkg locks... ($i/$tries)"
    sleep 2
  done
}

run_and_log() {
  # Logs everything to update.log AND shows output live
  # Requires: bash process substitution + tee
  # shellcheck disable=SC2064
  {
    echo "========================================"
    echo "Update started: $(date)"
    echo "Package manager: $pkg_manager"
    echo "========================================"
    echo
    "$@"
    echo
    echo "========================================"
    echo "Update finished: $(date)"
    echo "========================================"
  } 2>&1 | tee "$LOG_FILE"
}

case "$pkg_manager" in
  apt-get)
    wait_for_apt_locks
    run_and_log bash -c '
      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get update
      sudo apt-get -y upgrade
    '
    ;;
  dnf)
    run_and_log sudo dnf -y upgrade --refresh
    ;;
  yum)
    run_and_log sudo yum -y update
    ;;
  pacman)
    run_and_log sudo pacman -Syu --noconfirm
    ;;
  zypper)
    run_and_log sudo zypper --non-interactive update
    ;;
  *)
    err "Unsupported package manager: $pkg_manager"
    ;;
esac

echo "Package update output saved to $LOG_FILE"
exit 0
