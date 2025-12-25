#!/usr/bin/env bash
# create_user.sh — WGU D796 RQN1 Task 1 (Section A)
#
# a1: Create a local Linux user in the dev_group group and set an initial password.
# a2: Force a password change on first login and show /etc/passwd for verification.
# a3: Provide a demo mode that runs the rubric scenarios from this file.

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
  create_user.sh <username> [password]
  create_user.sh --demo [username] [password]

Notes:
  - Group: dev_group (created if missing)
  - Linux only (useradd/groupadd/chpasswd/chage)
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

# f8: user_exists — Return success when the user already exists.
user_exists() {
  id -u "$1" >/dev/null 2>&1
}

# f9: group_exists — Check if a group exists on Linux (getent preferred).
group_exists() {
  local group_name="$1"
  if command -v getent >/dev/null 2>&1; then
    getent group "$group_name" >/dev/null 2>&1
    return
  fi
  [[ -r /etc/group ]] && grep -qE "^${group_name}:" /etc/group
}

# f10: set_password — Assign a password or exit with a clear policy error.
set_password() {
  local username="$1"
  local password="$2"
  [[ -n "$password" ]] || err "Password must not be empty"

  if [[ "${EUID}" -ne 0 ]]; then
    printf '%s:%s\n' "$username" "$password" | sudo chpasswd || err "Password rejected by policy; pass a stronger password argument"
  else
    printf '%s:%s\n' "$username" "$password" | chpasswd || err "Password rejected by policy; pass a stronger password argument"
  fi
}

# f11: force_password_change — Require a password change at next login.
force_password_change() {
  local username="$1"
  if run_privileged chage -d 0 "$username" >/dev/null 2>&1; then
    return 0
  fi
  require_cmd passwd
  run_privileged passwd -e "$username" >/dev/null 2>&1 || err "Failed to force password change for user ${username}"
}

# f12: ensure_group — Ensure the dev_group group exists before user creation.
ensure_group() {
  local group_name="$1"
  if ! group_exists "$group_name"; then
    run_privileged groupadd "$group_name" || err "Failed to create group ${group_name}"
    echo "Group ${group_name} created."
  else
    echo "Group ${group_name} already exists."
  fi
}

# f13: show_passwd — Display /etc/passwd as required verification output.
show_passwd() {
  echo "---- /etc/passwd ----"
  cat /etc/passwd
}

# f14: switch_to_user — Attempt a login shell for the new user to show the forced password change.
switch_to_user() {
  local username="$1"

  echo
  echo "---- switch to ${username} ----"
  if ! command -v su >/dev/null 2>&1; then
    echo "su command not found; run manually: su - ${username}" >&2
    return 0
  fi

  if [[ -t 0 ]]; then
    if [[ "${EUID}" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]] && command -v sudo >/dev/null 2>&1; then
      echo "Switching as ${SUDO_USER} to prompt for ${username} password"
      sudo -iu "${SUDO_USER}" su - "${username}"
    else
      echo "Starting login shell for ${username}"
      su - "${username}"
    fi
  else
    echo "Non-interactive session; run manually: su - ${username}"
  fi
}

# f15: create_user — Validate inputs, create the account, and emit verification output.
create_user() {
  local username="$1"
  local password="$2"
  local password_source="$3"
  local group_name="dev_group"

  [[ -n "$username" && -n "$password" ]] || err "Username and password must be provided"
  validate_username "$username"
  user_exists "$username" && err "User already exists: $username"

  require_cmd groupadd
  require_cmd useradd
  require_cmd chpasswd

  ensure_sudo
  ensure_group "$group_name"

  run_privileged useradd -m -g "$group_name" "$username" || err "Failed to create user ${username}"
  echo "Assigned ${password_source} password for ${username}: ${password}"
  set_password "$username" "$password"
  force_password_change "$username"

  echo "User ${username} created successfully (password change required on first login)."
  echo
  show_passwd
  # f16a: Skip the login switch when SKIP_SWITCH is set for automation.
  if [[ "${SKIP_SWITCH:-}" != "1" ]]; then
    switch_to_user "$username"
  fi
}

# f16: demo_mode — Execute the rubric scenarios without external demo scripts.
demo_mode() {
  local demo_username="${1:-}"
  local demo_password="${2:-TempPass123!}"
  local script_path

  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  echo "Demo: create_user.sh requirements"
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

  echo "2) Run script with valid arguments (username + password):"
  echo "   Username: $demo_username"
  echo "   Assigned password: $demo_password"
  echo
  echo "3) Switch to the new user (login shell opens during the run):"
  echo "   Follow the password-change prompt after login."
  echo

  "$script_path" "$demo_username" "$demo_password"
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
    demo_mode "${1:-}" "${2:-}"
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

username="$1"
password="${2:-}"
password_source="provided"

DEFAULT_PASSWORD="TempPass123!"
if [[ -z "$password" ]]; then
  password="$DEFAULT_PASSWORD"
  password_source="default"
fi

create_user "$username" "$password" "$password_source"
exit 0
