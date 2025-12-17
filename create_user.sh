#!/usr/bin/env bash

# Safer bash settings:
# -e  : exit immediately if a command fails (non-zero status)
# -u  : treat unset variables as an error
# -o pipefail : if any command in a pipeline fails, the pipeline fails
set -euo pipefail

# Print an error message to stderr and exit with a non-zero status.
err() {
    echo "Error: $*" >&2
    exit 1
}

# Print how to run this script. (Sent to stderr so it still shows on errors.)
usage() {
    echo "Usage: $0 <username> [password]" >&2
    echo "  - If [password] is omitted, you'll be prompted." >&2
    echo "  - Creates/uses group: dev_group" >&2
}

# Fail fast if a required external command isn't available in PATH.
# `command -v` is a POSIX-ish way to check availability without running the command.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# This script uses Linux account-management tools (useradd/groupadd/chpasswd).
# On macOS, these commands either don't exist or behave differently.
require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This script is written for Linux (needs useradd/groupadd/chpasswd). You're on $(uname -s)."
    fi
}

# Returns success if the user exists, failure otherwise.
# `id -u <user>` exits 0 if the user exists, non-zero if not.
user_exists() {
    id -u "$1" >/dev/null 2>&1
}

# Returns success if the group exists.
# Prefer `getent` when available (works with LDAP/NSS), otherwise fall back to /etc/group.
group_exists() {
    local group_name="$1"
    if command -v getent >/dev/null 2>&1; then
        getent group "$group_name" >/dev/null 2>&1
        return
    fi
    [[ -r /etc/group ]] && grep -qE "^${group_name}:" /etc/group
}

# Prompt the user twice for a password without echoing characters (`read -s`).
# Prints the password to stdout so the caller can capture it.
prompt_password() {
    local username="$1"
    local pass1 pass2
    read -r -s -p "Enter password for ${username}: " pass1
    echo
    read -r -s -p "Confirm password: " pass2
    echo
    [[ -n "$pass1" ]] || err "Password must not be empty"
    [[ "$pass1" == "$pass2" ]] || err "Passwords do not match"
    printf '%s' "$pass1"
}

# Ensure we are running as root. If not:
# - re-run this same script via sudo
# - `exec` replaces the current process, so we don't keep running as the non-root user
# - "$@" expands to all original arguments exactly as passed
ensure_root_or_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

# Create a new Linux user and force a password change on first login.
create_user() {
    local username="$1"
    local password="$2"

    # Basic argument validation (empty strings should be rejected).
    if [[ -z "$username" || -z "$password" ]]; then
        err "Username and password must be provided"
    fi

    # Avoid clobbering an existing account.
    if user_exists "$username"; then
        err "User already exists: $username"
    fi

    # Validate environment before making system changes.
    require_linux
    require_cmd groupadd
    require_cmd useradd
    require_cmd chpasswd

    # Create the group once; ignore if it already exists.
    if ! group_exists "dev_group"; then
        groupadd "dev_group" || err "Failed to create group dev_group"
    fi

    # -m: create home directory
    # -g: set the primary group
    useradd -m -g "dev_group" "$username" || err "Failed to create user $username"

    # `chpasswd` reads "username:password" lines from stdin and updates /etc/shadow.
    # `printf` avoids issues with echo interpretation.
    printf '%s:%s\n' "$username" "$password" | chpasswd || err "Failed to set password for user $username"

    # Force password change on first login:
    # Prefer `chage` if present; otherwise fall back to `passwd -e`.
    if command -v chage >/dev/null 2>&1; then
        chage -d 0 "$username" || err "Failed to force password change for user $username"
    else
        require_cmd passwd
        passwd -e "$username" >/dev/null 2>&1 || err "Failed to force password change for user $username"
    fi

    echo "User $username created successfully (password change required on first login)."
    echo
    echo "---- /etc/passwd ----"
    # For demonstration/verification only; /etc/passwd lists local accounts.
    cat /etc/passwd
}

# Require at least 1 positional argument (the username).
if [[ $# -lt 1 ]]; then
    usage
    err "Username argument is required"
fi

# Must run before we read/use $1/$2 so the sudo re-run sees the same argv.
ensure_root_or_sudo "$@"

# $1 is the first positional argument (username).
username="$1"

# ${2:-} means "use $2 if set, otherwise use empty string".
password="${2:-}"

# If the password wasn't provided on the command line, prompt interactively.
if [[ -z "$password" ]]; then
    password="$(prompt_password "$username")"
fi

# Run the actual user creation function with the validated inputs.
create_user "$username" "$password"
