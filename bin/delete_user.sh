#!/usr/bin/env bash
set -euo pipefail

err() { echo "Error: $*" >&2; exit 1; }

usage() {
  echo "Usage: $0 <username>" >&2
  echo "  - Deletes the user account and home directory" >&2
  echo "  - Supported OS: Linux (userdel), macOS/Darwin (dscl)" >&2
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"; }

OS="$(uname -s)"

require_supported_os() {
  case "$OS" in
    Linux|Darwin) ;;
    *) err "Unsupported OS: $OS (supported: Linux, Darwin)" ;;
  esac
}

user_exists() { id -u "$1" >/dev/null 2>&1; }

ensure_root_or_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -- "$0" "$@"
  fi
}

confirm_delete() {
  local username="$1" reply
  read -r -p "Delete user '${username}' and their home directory? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) err "User deletion canceled" ;;
  esac
}

lookup_home_dir_linux() {
  local username="$1" entry=""
  if command -v getent >/dev/null 2>&1; then
    entry="$(getent passwd "${username}" || true)"
  elif [[ -r /etc/passwd ]]; then
    entry="$(grep -E "^${username}:" /etc/passwd || true)"
  fi
  [[ -n "$entry" ]] || { echo ""; return; }
  echo "$entry" | awk -F: '{print $6}'
}

lookup_home_dir_darwin() {
  local username="$1"
  dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

safe_remove_home_dir() {
  local home_dir="$1"
  [[ -n "$home_dir" ]] || err "Home directory argument missing"
  [[ "$home_dir" == /* ]] || err "Refusing to remove non-absolute home directory path: $home_dir"

  case "$home_dir" in
    /|/Users|/Users/Shared|/home) err "Refusing to remove unsafe home directory path: $home_dir" ;;
  esac

  if ! rm -rf -- "$home_dir"; then
    if [[ "$OS" == "Darwin" ]]; then
      err "Failed to remove home directory: $home_dir (grant Terminal Full Disk Access and retry)"
    fi
    err "Failed to remove home directory: $home_dir"
  fi
}

delete_user_linux() {
  local username="$1" home_dir
  require_cmd userdel
  require_cmd awk

  home_dir="$(lookup_home_dir_linux "$username")"
  [[ -n "$home_dir" ]] || err "Could not determine home directory for user: $username"

  userdel -r "$username" || err "Failed to delete user: $username"

  if [[ -e "$home_dir" ]]; then
    safe_remove_home_dir "$home_dir"
  fi
}

delete_user_darwin() {
  local username="$1" home_dir
  require_cmd dscl
  require_cmd awk

  home_dir="$(lookup_home_dir_darwin "$username")"
  [[ -n "$home_dir" ]] || err "Could not determine home directory for user: $username"

  if command -v sysadminctl >/dev/null 2>&1; then
    sysadminctl -deleteUser "$username" >/dev/null 2>&1 || dscl . -delete "/Users/${username}" || err "Failed to delete user record: $username"
  else
    dscl . -delete "/Users/${username}" || err "Failed to delete user record: $username"
  fi

  if [[ -e "$home_dir" ]]; then
    safe_remove_home_dir "$home_dir"
  fi
}

delete_user() {
  local username="$1"
  [[ -n "$username" ]] || err "Username must be provided"
  [[ "$username" != "root" ]] || err "Refusing to delete root user"
  user_exists "$username" || err "User does not exist: $username"

  require_supported_os

  case "$OS" in
    Linux)  delete_user_linux "$username" ;;
    Darwin) delete_user_darwin "$username" ;;
  esac
}

# ---- main ----
if [[ $# -lt 1 ]]; then
  usage
  err "Username argument is required"
fi

ensure_root_or_sudo "$@"

username="$1"
confirm_delete "$username"
delete_user "$username"

echo "User $username deleted successfully."
echo

echo "---- /etc/passwd ----"
cat /etc/passwd
echo

echo "Verification (should show NOT FOUND):"
echo "- id $username:"
if id "$username" >/dev/null 2>&1; then
  echo "Unexpected: user still exists according to id"
  id "$username"
else
  echo "OK: user not found by id"
fi

if [[ "$OS" == "Darwin" ]]; then
  echo
  echo "- dscl . -read /Users/$username:"
  if dscl . -read "/Users/${username}" >/dev/null 2>&1; then
    echo "Unexpected: user still exists in Directory Services"
    dscl . -read "/Users/${username}" 2>/dev/null || true
  else
    echo "OK: user not found in Directory Services"
  fi
fi

exit 0
