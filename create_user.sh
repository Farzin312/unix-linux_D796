#!/usr/bin/env bash

# I enable strict mode so I notice errors early and avoid partial user setup.
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
    echo "  - Supported OS: Linux (useradd/groupadd), macOS/Darwin (dscl/dseditgroup)" >&2
}

# Fail fast if a required external command isn't available in PATH.
# `command -v` is a POSIX-ish way to check availability without running the command.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# Detect OS once so we can choose the right user/group management tools.
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
# `id -u <user>` exits 0 if the user exists, non-zero if not.
user_exists() {
    id -u "$1" >/dev/null 2>&1
}

# Returns success if a Linux group exists.
# Prefer `getent` when available (works with LDAP/NSS), otherwise fall back to /etc/group.
group_exists_linux() {
    local group_name="$1"
    if command -v getent >/dev/null 2>&1; then
        getent group "$group_name" >/dev/null 2>&1
        return
    fi
    [[ -r /etc/group ]] && grep -qE "^${group_name}:" /etc/group
}

# Returns success if a macOS group exists in Directory Services.
group_exists_darwin() {
    local group_name="$1"
    dscl . -read "/Groups/${group_name}" >/dev/null 2>&1
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

# Find the next available numeric ID on macOS by reading existing IDs and picking max+1.
# This is a common pattern when creating users/groups via `dscl`.
darwin_next_id() {
    local list_cmd="$1"
    local max_id
    max_id="$($list_cmd 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1)"
    if [[ -z "${max_id}" ]]; then
        echo "501"
        return
    fi
    echo "$((max_id + 1))"
}

# Create the dev_group on macOS if it doesn't exist, and print its PrimaryGroupID.
ensure_group_darwin() {
    local group_name="$1"

    require_cmd dscl
    require_cmd awk
    require_cmd sort
    require_cmd tail

    if ! group_exists_darwin "$group_name"; then
        local gid
        gid="$(darwin_next_id "dscl . -list /Groups PrimaryGroupID")"
        dscl . -create "/Groups/${group_name}" || err "Failed to create group ${group_name}"
        dscl . -create "/Groups/${group_name}" RealName "${group_name}" || err "Failed to set group RealName"
        dscl . -create "/Groups/${group_name}" PrimaryGroupID "${gid}" || err "Failed to set group PrimaryGroupID"
        dscl . -create "/Groups/${group_name}" Password "*" || err "Failed to set group Password"
    fi

    dscl . -read "/Groups/${group_name}" PrimaryGroupID 2>/dev/null | awk '{print $2}'
}

# Create a new user on macOS using Directory Services tools.
create_user_darwin() {
    local username="$1"
    local password="$2"
    local group_name="$3"

    require_cmd dscl
    require_cmd createhomedir

    local gid uid home shell
    gid="$(ensure_group_darwin "$group_name")"
    [[ -n "$gid" ]] || err "Could not determine PrimaryGroupID for ${group_name}"

    home="/Users/${username}"
    shell="/bin/zsh"

    # Prefer Apple's supported tool if available; fall back to `dscl` if needed.
    if command -v sysadminctl >/dev/null 2>&1; then
        if sysadminctl -addUser "${username}" -password "${password}" -home "${home}" -shell "${shell}" -fullName "${username}" >/dev/null 2>&1; then
            :
        else
            # Some macOS setups restrict user creation via sysadminctl; fall back to Directory Services creation.
            uid="$(darwin_next_id "dscl . -list /Users UniqueID")"
            dscl . -create "/Users/${username}" || err "Failed to create user record ${username}"
            dscl . -create "/Users/${username}" UserShell "${shell}" || err "Failed to set UserShell"
            dscl . -create "/Users/${username}" RealName "${username}" || err "Failed to set RealName"
            dscl . -create "/Users/${username}" UniqueID "${uid}" || err "Failed to set UniqueID"
            dscl . -create "/Users/${username}" PrimaryGroupID "${gid}" || err "Failed to set PrimaryGroupID"
            dscl . -create "/Users/${username}" NFSHomeDirectory "${home}" || err "Failed to set NFSHomeDirectory"
        fi
    else
        uid="$(darwin_next_id "dscl . -list /Users UniqueID")"
        dscl . -create "/Users/${username}" || err "Failed to create user record ${username}"
        dscl . -create "/Users/${username}" UserShell "${shell}" || err "Failed to set UserShell"
        dscl . -create "/Users/${username}" RealName "${username}" || err "Failed to set RealName"
        dscl . -create "/Users/${username}" UniqueID "${uid}" || err "Failed to set UniqueID"
        dscl . -create "/Users/${username}" PrimaryGroupID "${gid}" || err "Failed to set PrimaryGroupID"
        dscl . -create "/Users/${username}" NFSHomeDirectory "${home}" || err "Failed to set NFSHomeDirectory"
    fi

    # Ensure key attributes are set consistently even if sysadminctl created the user.
    dscl . -create "/Users/${username}" UserShell "${shell}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" NFSHomeDirectory "${home}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" PrimaryGroupID "${gid}" >/dev/null 2>&1 || true

    # Ensure the account can authenticate with a password in Terminal tools like `su`.
    # Some macOS versions won't generate the needed auth attributes unless AuthenticationAuthority exists.
    local auth
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    if [[ -z "$auth" ]]; then
        dscl . -create "/Users/${username}" AuthenticationAuthority ";ShadowHash;" >/dev/null 2>&1 || true
    fi
    dscl . -passwd "/Users/${username}" "${password}" >/dev/null 2>&1 || err "Failed to set password for user ${username}"
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    [[ "$auth" == *ShadowHash* ]] || err "macOS account created but password authentication is not configured (missing ShadowHash)"

    # Create the home directory and populate default files (if applicable).
    createhomedir -c -u "${username}" >/dev/null 2>&1 || true

    # Ensure the user is a member of the group (in addition to PrimaryGroupID).
    if command -v dseditgroup >/dev/null 2>&1; then
        dseditgroup -o edit -a "${username}" -t user "${group_name}" >/dev/null 2>&1 || err "Failed to add ${username} to group ${group_name}"
    fi

    # Best-effort "force password change" on macOS; not all setups enforce this uniformly.
    if command -v pwpolicy >/dev/null 2>&1; then
        pwpolicy -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || pwpolicy -n /Local/Default -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || true
    fi
}

# Create a new user on Linux using shadow-utils tools.
create_user_linux() {
    local username="$1"
    local password="$2"
    local group_name="$3"

    require_cmd groupadd
    require_cmd useradd
    require_cmd chpasswd

    # Create the group once; ignore if it already exists.
    if ! group_exists_linux "${group_name}"; then
        groupadd "${group_name}" || err "Failed to create group ${group_name}"
    fi

    # -m: create home directory
    # -g: set the primary group
    useradd -m -g "${group_name}" "${username}" || err "Failed to create user ${username}"

    # `chpasswd` reads "username:password" lines from stdin and updates /etc/shadow.
    # `printf` avoids issues with echo interpretation.
    printf '%s:%s\n' "${username}" "${password}" | chpasswd || err "Failed to set password for user ${username}"

    # Force password change on first login:
    # Prefer `chage` if present; otherwise fall back to `passwd -e`.
    if command -v chage >/dev/null 2>&1; then
        chage -d 0 "${username}" || err "Failed to force password change for user ${username}"
    else
        require_cmd passwd
        passwd -e "${username}" >/dev/null 2>&1 || err "Failed to force password change for user ${username}"
    fi
}

# Create a new Linux user and force a password change on first login.
create_user() {
    local username="$1"
    local password="$2"
    local group_name="dev_group"
    local password_change_msg

    # Basic argument validation (empty strings should be rejected).
    if [[ -z "$username" || -z "$password" ]]; then
        err "Username and password must be provided"
    fi

    # Avoid clobbering an existing account.
    if user_exists "$username"; then
        err "User already exists: $username"
    fi

    # Validate environment before making system changes.
    require_supported_os

    case "$(os_name)" in
        Linux)
            create_user_linux "${username}" "${password}" "${group_name}"
            password_change_msg="password change required on first login"
            ;;
        Darwin)
            create_user_darwin "${username}" "${password}" "${group_name}"
            password_change_msg="password change policy attempted (macOS enforcement may vary)"
            ;;
        *) err "Unsupported OS: $(os_name)" ;;
    esac

    echo "User $username created successfully (${password_change_msg})."
    echo
    echo "---- /etc/passwd ----"
    # For demonstration/verification only; /etc/passwd lists local accounts.
    cat /etc/passwd

    # On macOS, local accounts may not be visible in /etc/passwd, so show Directory Services info too.
    if [[ "$(os_name)" == "Darwin" ]]; then
        echo
        echo "---- id ${username} ----"
        id "${username}" || true
        echo
        echo "---- dscl /Users/${username} ----"
        dscl . -read "/Users/${username}" UniqueID PrimaryGroupID NFSHomeDirectory UserShell 2>/dev/null || true
    fi
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

# Explicit success exit (script will naturally end here, but this makes intent clear).
exit 0
