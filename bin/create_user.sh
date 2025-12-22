#!/usr/bin/env bash
# create_user.sh — WGU D796 RQN1 Task 1 (A)
#
# a1: Create a local user account and ensure membership in the `dev_group` group.
# a2: Support Linux (useradd/groupadd/chage) and macOS/Darwin (dscl/sysadminctl/pwpolicy).
# a3: Elevate privileges with sudo when not running as root.

set -euo pipefail  # a4: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
    echo "Error: $*" >&2
    exit 1
}

# f2: usage — Print CLI usage information to stderr.
usage() {
    echo "Usage: $0 <username> [password]" >&2
    echo "  - If [password] is omitted, a prompt is shown." >&2
    echo "  - Creates/uses group: dev_group" >&2
    echo "  - Supported OS: Linux (useradd/groupadd), macOS/Darwin (dscl/dseditgroup)" >&2
}

# f3: require_cmd — Verify a required command exists on PATH.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# f4: os_name — Return the current OS name (uname -s).
os_name() {
    uname -s
}

# f5: require_supported_os — Abort on unsupported operating systems.
require_supported_os() {
    case "$(os_name)" in
        Linux|Darwin) ;;
        *) err "Unsupported OS: $(os_name) (supported: Linux, Darwin)" ;;
    esac
}

# f6: validate_username — Validate the username format to keep behavior predictable and avoid unsafe characters.
validate_username() {
    local username="$1"
    [[ -n "$username" ]] || err "Username must not be empty"
    # a5: Apply a common Linux/macOS-safe rule: starts with letter/_ then letters/numbers/_/-.
    if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        err "Invalid username: '$username' (allowed: letters, numbers, underscore, dash; must start with letter/underscore)"
    fi
}

# f7: user_exists — Return success when the user already exists.
user_exists() {
    id -u "$1" >/dev/null 2>&1
}

# f8: group_exists_linux — Check if a group exists on Linux (getent preferred, /etc/group fallback).
group_exists_linux() {
    local group_name="$1"
    if command -v getent >/dev/null 2>&1; then
        getent group "$group_name" >/dev/null 2>&1
        return
    fi
    [[ -r /etc/group ]] && grep -qE "^${group_name}:" /etc/group
}

# f9: group_exists_darwin — Check if a group exists on macOS using Directory Services.
group_exists_darwin() {
    local group_name="$1"
    dscl . -read "/Groups/${group_name}" >/dev/null 2>&1
}

# f10: prompt_password — Prompt twice and return a confirmed password (no echo).
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

# f11: ensure_root_or_sudo — Re-exec the script under sudo when not running as root.
ensure_root_or_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

# f12: darwin_next_id — Return the next available UID/GID for macOS by scanning existing IDs.
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

# f13: ensure_group_darwin — Ensure the group exists on macOS and return its PrimaryGroupID.
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

# f14: create_user_darwin — Create a user on macOS and add it to the target group.
create_user_darwin() {
    local username="$1"
    local password="$2"
    local group_name="$3"

    require_cmd dscl
    require_cmd createhomedir

    local gid uid home shell
    # a6: Determine group ID and default user properties.
    gid="$(ensure_group_darwin "$group_name")"
    [[ -n "$gid" ]] || err "Could not determine PrimaryGroupID for ${group_name}"

    home="/Users/${username}"
    shell="/bin/zsh"

    # a7: Prefer sysadminctl when available; fall back to dscl record creation when needed.
    if command -v sysadminctl >/dev/null 2>&1; then
        if sysadminctl -addUser "${username}" -password "${password}" -home "${home}" -shell "${shell}" -fullName "${username}" >/dev/null 2>&1; then
            :
        else
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

    # a8: Re-assert essential attributes to reduce partial-record drift across tools.
    dscl . -create "/Users/${username}" UserShell "${shell}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" NFSHomeDirectory "${home}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" PrimaryGroupID "${gid}" >/dev/null 2>&1 || true

    # a9: Ensure password authentication is enabled (ShadowHash) before setting the password.
    local auth
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    if [[ -z "$auth" ]]; then
        dscl . -create "/Users/${username}" AuthenticationAuthority ";ShadowHash;" >/dev/null 2>&1 || true
    fi

    dscl . -passwd "/Users/${username}" "${password}" >/dev/null 2>&1 || err "Failed to set password for user ${username}"
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    [[ "$auth" == *ShadowHash* ]] || err "macOS account created but password authentication is not configured (missing ShadowHash)"

    createhomedir -c -u "${username}" >/dev/null 2>&1 || true

    # a10: Add the user to the target group (when dseditgroup is available).
    if command -v dseditgroup >/dev/null 2>&1; then
        dseditgroup -o edit -a "${username}" -t user "${group_name}" >/dev/null 2>&1 || err "Failed to add ${username} to group ${group_name}"
    fi

    # a11: Attempt to require a password change at next login (policy enforcement varies by system).
    if command -v pwpolicy >/dev/null 2>&1; then
        pwpolicy -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || pwpolicy -n /Local/Default -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || true
    fi
}

# f15: create_user_linux — Create a user on Linux, set a password, and force a password change on first login.
create_user_linux() {
    local username="$1"
    local password="$2"
    local group_name="$3"

    require_cmd groupadd
    require_cmd useradd
    require_cmd chpasswd

    # a12: Ensure the target group exists before creating the user.
    if ! group_exists_linux "${group_name}"; then
        groupadd "${group_name}" || err "Failed to create group ${group_name}"
    fi

    # a13: Create the user and assign the initial password.
    useradd -m -g "${group_name}" "${username}" || err "Failed to create user ${username}"
    printf '%s:%s\n' "${username}" "${password}" | chpasswd || err "Failed to set password for user ${username}"

    # a14: Force password change on first login (chage preferred, passwd fallback).
    if command -v chage >/dev/null 2>&1; then
        chage -d 0 "${username}" || err "Failed to force password change for user ${username}"
    else
        require_cmd passwd
        passwd -e "${username}" >/dev/null 2>&1 || err "Failed to force password change for user ${username}"
    fi
}

# f16: create_user — Validate inputs, dispatch to OS-specific creation, then print verification output.
create_user() {
    local username="$1"
    local password="$2"
    local group_name="dev_group"
    local password_change_msg

    [[ -n "$username" && -n "$password" ]] || err "Username and password must be provided"
    validate_username "$username"

    if user_exists "$username"; then
        err "User already exists: $username"
    fi

    require_supported_os

    # a15: Dispatch to the OS-specific implementation.
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

    # a16: Print creation confirmation and verification output requested by the task.
    echo "User $username created successfully (${password_change_msg})."
    echo
    echo "---- /etc/passwd ----"
    cat /etc/passwd

    if [[ "$(os_name)" == "Darwin" ]]; then
        # a17: Emit macOS-specific verification details when available.
        echo
        echo "---- id ${username} ----"
        id "${username}" || true
        echo
        echo "---- dscl /Users/${username} ----"
        dscl . -read "/Users/${username}" UniqueID PrimaryGroupID NFSHomeDirectory UserShell 2>/dev/null || true
    fi
}

# a18: Validate CLI args and show usage on missing username.
if [[ $# -lt 1 ]]; then
    usage
    err "Username argument is required"
fi

# a19: Ensure permissions allow user/group management operations.
ensure_root_or_sudo "$@"

# a20: Parse and validate args.
username="$1"
password="${2:-}"

validate_username "$username"

# a21: Prompt for a password only when not provided as an argument.
if [[ -z "$password" ]]; then
    password="$(prompt_password "$username")"
fi

# a22: Create the user and emit verification output.
create_user "$username" "$password"
exit 0
