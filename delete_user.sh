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
    echo "Usage: $0 <username>" >&2
    echo "  - Deletes the user account and home directory" >&2
    echo "  - Supported OS: Linux (userdel), macOS/Darwin (dscl)" >&2
}

# Fail fast if a required external command isn't available in PATH.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# Detect OS once so we can choose the right user management tools.
os_name() {
    uname -s
}

# Validate that we're on a supported OS.
require_supported_os() {
    case "$(os_name)" in
        Linux | Darwin) ;;
        *) err "Unsupported OS: $(os_name) (supported: Linux, Darwin)" ;;
    esac
}

# Returns success if the user exists, failure otherwise.
user_exists() {
    id -u "$1" >/dev/null 2>&1
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

# Prompt for confirmation before deleting a user.
confirm_delete() {
    local username="$1"
    local reply
    read -r -p "Delete user '${username}' and their home directory? [y/N] " reply
    case "$reply" in
        [yY] | [yY][eE][sS]) ;;
        *) err "User deletion canceled" ;;
    esac
}

# Lookup the user's home directory on Linux via getent or /etc/passwd.
lookup_home_dir_linux() {
    local username="$1"
    local entry=""

    if command -v getent >/dev/null 2>&1; then
        entry="$(getent passwd "${username}" || true)"
    elif [[ -r /etc/passwd ]]; then
        entry="$(grep -E "^${username}:" /etc/passwd || true)"
    fi

    if [[ -z "$entry" ]]; then
        echo ""
        return
    fi

    echo "$entry" | awk -F: '{print $6}'
}

# Lookup the user's home directory on macOS via Directory Services.
lookup_home_dir_darwin() {
    local username="$1"
    dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

# Remove a home directory with basic safety checks.
safe_remove_home_dir() {
    local home_dir="$1"

    [[ -n "$home_dir" ]] || err "Home directory argument missing"
    [[ "$home_dir" == /* ]] || err "Refusing to remove non-absolute home directory path: $home_dir"

    case "$home_dir" in
        / | /Users | /Users/Shared | /home)
            err "Refusing to remove unsafe home directory path: $home_dir"
            ;;
    esac

    if ! rm -rf -- "$home_dir"; then
        if [[ "$(os_name)" == "Darwin" ]]; then
            err "Failed to remove home directory: $home_dir (grant Terminal Full Disk Access and retry)"
        fi
        err "Failed to remove home directory: $home_dir"
    fi
}

# Delete a user on Linux and remove their home directory.
delete_user_linux() {
    local username="$1"
    local home_dir

    require_cmd userdel
    require_cmd awk

    home_dir="$(lookup_home_dir_linux "$username")"
    [[ -n "$home_dir" ]] || err "Could not determine home directory for user: $username"

    # -r: remove home directory and mail spool
    userdel -r "$username" || err "Failed to delete user: $username"

    # Some setups may not remove the home directory; clean up if it remains.
    if [[ -e "$home_dir" ]]; then
        safe_remove_home_dir "$home_dir"
    fi
}

# Delete a user on macOS and remove their home directory.
delete_user_darwin() {
    local username="$1"
    local home_dir

    require_cmd dscl
    require_cmd awk

    home_dir="$(lookup_home_dir_darwin "$username")"
    [[ -n "$home_dir" ]] || err "Could not determine home directory for user: $username"

    if command -v sysadminctl >/dev/null 2>&1; then
        if sysadminctl -deleteUser "$username" >/dev/null 2>&1; then
            :
        else
            dscl . -delete "/Users/${username}" || err "Failed to delete user record: $username"
        fi
    else
        dscl . -delete "/Users/${username}" || err "Failed to delete user record: $username"
    fi

    if [[ -e "$home_dir" ]]; then
        safe_remove_home_dir "$home_dir"
    fi
}

# Delete a user and their home directory (OS-aware).
delete_user() {
    local username="$1"

    if [[ -z "$username" ]]; then
        err "Username must be provided"
    fi

    if [[ "$username" == "root" ]]; then
        err "Refusing to delete root user"
    fi

    if ! user_exists "$username"; then
        err "User does not exist: $username"
    fi

    require_supported_os

    case "$(os_name)" in
        Linux)
            delete_user_linux "$username"
            ;;
        Darwin)
            delete_user_darwin "$username"
            ;;
        *) err "Unsupported OS: $(os_name)" ;;
    esac
}

# Require at least 1 positional argument (the username).
if [[ $# -lt 1 ]]; then
    usage
    err "Username argument is required"
fi

# Must run before we read/use $1 so the sudo re-run sees the same argv.
ensure_root_or_sudo "$@"

# $1 is the first positional argument (username).
username="$1"

confirm_delete "$username"

# Run the actual user deletion function with the validated input.
delete_user "$username"

echo "User $username deleted successfully."
echo

echo "---- /etc/passwd ----"
cat /etc/passwd

# On macOS, local accounts may not be visible in /etc/passwd, so show Directory Services info too.
if [[ "$(os_name)" == "Darwin" ]]; then
    echo
    echo "---- id ${username} ----"
    if id "$username" >/dev/null 2>&1; then
        id "$username"
    else
        echo "User ${username} not found (id returned non-zero)."
    fi
    echo
    echo "---- dscl /Users/${username} ----"
    if dscl . -read "/Users/${username}" >/dev/null 2>&1; then
        dscl . -read "/Users/${username}" 2>/dev/null
    else
        echo "User ${username} not found in Directory Services."
    fi
fi

# Explicit success exit (script will naturally end here, but this makes intent clear).
exit 0
