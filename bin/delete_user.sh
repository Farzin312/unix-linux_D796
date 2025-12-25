#!/usr/bin/env bash
# delete_user.sh — WGU D796 RQN1 Task 1 (Section B)
#
# b1: Delete a local Linux user and home directory with confirmation.
# b2: Terminate user processes before deletion to avoid userdel failures.
# b3: Provide a demo mode that runs the rubric scenarios from this file.

set -euo pipefail

# f1: err — Print an error message to stderr and exit non-zero.
err() {
  echo "Error: $*" >&2
  exit 1
}

# f2: usage — Print CLI usage information to stderr.
usage() {
  cat >&2 <<'USAGE'
Usage:
  delete_user.sh <username>
  delete_user.sh --demo [username]

Notes:
  - Deletes the user account and home directory
  - Linux only (userdel)
USAGE
}

# f3: require_cmd — Verify a required command exists on PATH.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# f4: require_linux — Exit when not running on Linux.
require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || err "This script targets Linux systems."
}

# f5: run_privileged — Run a command with sudo when not root.
run_privileged() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# f6: ensure_sudo — Validate sudo credentials before privileged commands.
ensure_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    require_cmd sudo
    sudo -v || err "sudo authentication failed"
  fi
}

# f7: validate_username — Validate the username format for safe user management.
validate_username() {
  local username="$1"
  [[ -n "$username" ]] || err "Username must not be empty"
  if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
    err "Invalid username: '$username' (allowed: letters, numbers, underscore, dash; must start with letter/underscore)"
  fi
}

# f8: user_exists — Return success when the user exists.
user_exists() {
  id -u "$1" >/dev/null 2>&1
}

# f9: confirm_delete — Require an explicit confirmation before any destructive action.
confirm_delete() {
  local username="$1" reply
  read -r -p "Delete user '${username}' and their home directory? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) err "User deletion canceled" ;;
  esac
}

# f10: lookup_home_dir — Resolve the user's home directory from passwd sources.
lookup_home_dir() {
  local username="$1" entry=""
  if command -v getent >/dev/null 2>&1; then
    entry="$(getent passwd "${username}" || true)"
  elif [[ -r /etc/passwd ]]; then
    entry="$(grep -E "^${username}:" /etc/passwd || true)"
  fi
  [[ -n "$entry" ]] || { echo ""; return; }
  echo "$entry" | awk -F: '{print $6}'
}

# f11: safe_remove_home_dir — Remove the home directory with guardrails.
safe_remove_home_dir() {
  local home_dir="$1"
  [[ -n "$home_dir" ]] || err "Home directory argument missing"
  [[ "$home_dir" == /* ]] || err "Refusing to remove non-absolute home directory path: $home_dir"

  case "$home_dir" in
    /|/home|/root) err "Refusing to remove unsafe home directory path: $home_dir" ;;
  esac

  run_privileged rm -rf -- "$home_dir" || err "Failed to remove home directory: $home_dir"
}

# f12: terminate_user_processes — Stop running processes owned by the target user.
terminate_user_processes() {
  local username="$1"

  if ! command -v pgrep >/dev/null 2>&1 || ! command -v pkill >/dev/null 2>&1; then
    return 0
  fi

  if pgrep -u "$username" >/dev/null 2>&1; then
    echo "Active processes found for ${username}:"
    pgrep -u "$username" -a || true
    echo "Stopping processes for ${username}..."
    run_privileged pkill -u "$username" || true
    sleep 1
    if pgrep -u "$username" >/dev/null 2>&1; then
      echo "Force stopping remaining processes for ${username}..."
      run_privileged pkill -9 -u "$username" || true
    fi
  fi
}

# f13: show_passwd — Display /etc/passwd as required verification output.
show_passwd() {
  echo "---- /etc/passwd ----"
  cat /etc/passwd
}

# f14: verify_deletion — Confirm the user is gone and attempt a login switch.
verify_deletion() {
  local username="$1"

  echo
  echo "Verification (should show NOT FOUND):"
  echo "- id $username:"
  if id "$username" >/dev/null 2>&1; then
    echo "Unexpected: user still exists according to id"
    id "$username" || true
  else
    echo "OK: user not found by id"
  fi

  echo
  echo "- su - $username -c whoami:"
  if ! command -v su >/dev/null 2>&1; then
    echo "su command not found; manual check required" >&2
    return 0
  fi

  if id "$username" >/dev/null 2>&1; then
    echo "User still exists; skipping su check to avoid a password prompt"
    return 0
  fi

  set +e
  su - "$username" -c "whoami" >/dev/null 2>&1
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "Unexpected: switch succeeded (user may not have been deleted)"
  else
    echo "OK: switch failed (user deleted)"
  fi
}

# f15: delete_user — Validate inputs, delete the account, and emit verification output.
delete_user() {
  local username="$1"
  local home_dir

  validate_username "$username"
  [[ "$username" != "root" ]] || err "Refusing to delete root user"
  [[ "$username" != "$(id -un)" ]] || err "Refusing to delete the current user"
  user_exists "$username" || err "User does not exist: $username"

  require_cmd userdel
  ensure_sudo

  home_dir="$(lookup_home_dir "$username")"
  [[ -n "$home_dir" ]] || err "Could not determine home directory for user: $username"

  confirm_delete "$username"
  terminate_user_processes "$username"
  run_privileged userdel -r "$username" || err "Failed to delete user: $username"

  if [[ -e "$home_dir" ]]; then
    safe_remove_home_dir "$home_dir"
  fi

  echo "User ${username} deleted successfully."
  echo
  show_passwd
  verify_deletion "$username"
}

# f16: demo_mode — Execute the rubric scenarios without external demo scripts.
demo_mode() {
  local demo_username="${1:-}"
  local script_path create_script

  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  create_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/create_user.sh"

  echo "Demo: delete_user.sh requirements"
  echo "Detected OS: $(uname -s)"
  echo

  echo "1) Run script without arguments (should error):"
  set +e
  "$script_path"
  status=$?
  set -e
  echo "Exit status: $status"
  echo

  if [[ -z "$demo_username" ]]; then
    demo_username="demo_user_$(date +%s)"
  fi

  if ! user_exists "$demo_username"; then
    if [[ -x "$create_script" ]]; then
      echo "Creating demo user for deletion: $demo_username"
      echo
      SKIP_SWITCH=1 "$create_script" "$demo_username" "TempPass123!"
      echo
    else
      err "create_user.sh not found beside delete_user.sh; provide a username that already exists"
    fi
  fi

  echo "2) Run script with valid arguments (username):"
  echo "   Username: $demo_username"
  echo "   A confirmation prompt is expected before deletion."
  echo
  echo "3) Attempt to switch to the deleted user (performed during the run):"
  echo
  "$script_path" "$demo_username"
}

# main: parse args and dispatch.
require_linux

if [[ $# -lt 1 ]]; then
  usage
  err "Username argument is required"
fi

case "$1" in
  --demo)
    shift
    demo_mode "${1:-}"
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    :
    ;;
 esac

delete_user "$1"
exit 0
