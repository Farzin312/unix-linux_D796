#!/usr/bin/env bash
# create_user.sh — WGU D796 RQN1 Task 1 (A)
# Supports Linux + macOS (Darwin)

set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    echo "Usage: $0 <username> [password]" >&2
    echo "  - If [password] is omitted, you'll be prompted." >&2
    echo "  - Creates/uses group: dev_group" >&2
    echo "  - Supported OS: Linux (useradd/groupadd), macOS/Darwin (dscl/dseditgroup)" >&2
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

os_name() {
    uname -s
}

require_supported_os() {
    case "$(os_name)" in
        Linux|Darwin) ;;
        *) err "Unsupported OS: $(os_name) (supported: Linux, Darwin)" ;;
    esac
}

# Basic username sanity check (keeps script behavior predictable)
validate_username() {
    local username="$1"
    [[ -n "$username" ]] || err "Username must not be empty"
    # Common Linux/macOS-safe username rule: starts with letter/_ then letters/numbers/_/-
    if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        err "Invalid username: '$username' (allowed: letters, numbers, underscore, dash; must start with letter/underscore)"
    fi
}

user_exists() {
    id -u "$1" >/dev/null 2>&1
}

group_exists_linux() {
    local group_name="$1"
    if command -v getent >/dev/null 2>&1; then
        getent group "$group_name" >/dev/null 2>&1
        return
    fi
    [[ -r /etc/group ]] && grep -qE "^${group_name}:" /etc/group
}

group_exists_darwin() {
    local group_name="$1"
    dscl . -read "/Groups/${group_name}" >/dev/null 2>&1
}

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

ensure_root_or_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

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

    dscl . -create "/Users/${username}" UserShell "${shell}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" NFSHomeDirectory "${home}" >/dev/null 2>&1 || true
    dscl . -create "/Users/${username}" PrimaryGroupID "${gid}" >/dev/null 2>&1 || true

    local auth
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    if [[ -z "$auth" ]]; then
        dscl . -create "/Users/${username}" AuthenticationAuthority ";ShadowHash;" >/dev/null 2>&1 || true
    fi

    dscl . -passwd "/Users/${username}" "${password}" >/dev/null 2>&1 || err "Failed to set password for user ${username}"
    auth="$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null || true)"
    [[ "$auth" == *ShadowHash* ]] || err "macOS account created but password authentication is not configured (missing ShadowHash)"

    createhomedir -c -u "${username}" >/dev/null 2>&1 || true

    if command -v dseditgroup >/dev/null 2>&1; then
        dseditgroup -o edit -a "${username}" -t user "${group_name}" >/dev/null 2>&1 || err "Failed to add ${username} to group ${group_name}"
    fi

    if command -v pwpolicy >/dev/null 2>&1; then
        pwpolicy -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || pwpolicy -n /Local/Default -u "${username}" -setpolicy "newPasswordRequired=1" >/dev/null 2>&1 \
            || true
    fi
}

create_user_linux() {
    local username="$1"
    local password="$2"
    local group_name="$3"

    require_cmd groupadd
    require_cmd useradd
    require_cmd chpasswd

    if ! group_exists_linux "${group_name}"; then
        groupadd "${group_name}" || err "Failed to create group ${group_name}"
    fi

    useradd -m -g "${group_name}" "${username}" || err "Failed to create user ${username}"
    printf '%s:%s\n' "${username}" "${password}" | chpasswd || err "Failed to set password for user ${username}"

    if command -v chage >/dev/null 2>&1; then
        chage -d 0 "${username}" || err "Failed to force password change for user ${username}"
    else
        require_cmd passwd
        passwd -e "${username}" >/dev/null 2>&1 || err "Failed to force password change for user ${username}"
    fi
}

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
    cat /etc/passwd

    if [[ "$(os_name)" == "Darwin" ]]; then
        echo
        echo "---- id ${username} ----"
        id "${username}" || true
        echo
        echo "---- dscl /Users/${username} ----"
        dscl . -read "/Users/${username}" UniqueID PrimaryGroupID NFSHomeDirectory UserShell 2>/dev/null || true
    fi
}

if [[ $# -lt 1 ]]; then
    usage
    err "Username argument is required"
fi

ensure_root_or_sudo "$@"

username="$1"
password="${2:-}"

validate_username "$username"

if [[ -z "$password" ]]; then
    password="$(prompt_password "$username")"
fi

create_user "$username" "$password"
exit 0
