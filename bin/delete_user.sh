#!/usr/bin/env bash
#
# a1: Delete a local user account and remove its home directory (Linux or macOS/Darwin).
# a2: Validate the target, request confirmation, then run an OS-specific deletion path.
set -euo pipefail  # a3: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() { echo "Error: $*" >&2; exit 1; }

# f2: usage — Print CLI usage information to stderr.
usage() {
  echo "Usage: $0 <username>" >&2
  echo "  - Deletes the user account and home directory" >&2
  echo "  - Supported OS: Linux (userdel), macOS/Darwin (dscl)" >&2
}

# f3: require_cmd — Verify a required command exists on PATH.
require_cmd() { command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"; }

# a4: Cache OS name for consistent branching behavior.
OS="$(uname -s)"

# f4: require_supported_os — Abort on unsupported operating systems.
require_supported_os() {
  case "$OS" in
    Linux|Darwin) ;;
    *) err "Unsupported OS: $OS (supported: Linux, Darwin)" ;;
  esac
}

# f5: user_exists — Return success when the user exists.
user_exists() { id -u "$1" >/dev/null 2>&1; }

# f6: ensure_root_or_sudo — Re-exec the script under sudo when not running as root.
ensure_root_or_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -- "$0" "$@"
  fi
}

# f7: confirm_delete — Require an explicit confirmation before any destructive action.
confirm_delete() {
  local username="$1" reply
  read -r -p "Delete user '${username}' and their home directory? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) err "User deletion canceled" ;;
  esac
}

# f8: lookup_home_dir_linux — Resolve the user's home directory from passwd sources (getent preferred).
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

# f9: lookup_home_dir_darwin — Resolve the user's home directory from Directory Services.
lookup_home_dir_darwin() {
  local username="$1"
  dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

# f10: safe_remove_home_dir — Remove the home directory with guardrails against unsafe paths.
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

# f11: delete_user_linux — Delete a Linux user and remove the home directory.
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

# f12: delete_user_darwin — Delete a macOS user and remove the home directory.
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

# f13: delete_user — Validate inputs and dispatch to OS-specific deletion.
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

# a5: main — Parse args, elevate privileges, confirm, delete, and verify.
# a6: Validate CLI args and show usage on missing username.
if [[ $# -lt 1 ]]; then
  usage
  err "Username argument is required"
fi

# a7: Ensure permissions allow user management operations.
ensure_root_or_sudo "$@"

# a8: Parse args and run the confirmation gate before deletion.
username="$1"
confirm_delete "$username"
delete_user "$username"

# a9: Emit verification output requested by the task.
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
