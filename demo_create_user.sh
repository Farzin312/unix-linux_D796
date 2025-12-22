#!/usr/bin/env bash
# demo_create_user.sh — WGU D796 RQN1 Task 1 (A5 demo)
# Demonstrates:
# 1) Run create_user.sh without args (shows error)
# 2) Run create_user.sh with valid args (username + password)
# 3) Switch to the new user (macOS: sudo -iu, Linux: su -)
#
# Critical: Forces the demo to use the PROJECT version (./bin/create_user.sh),
# not some other copy in /usr/local/bin.

set -euo pipefail

err() {
  echo "Error: $*" >&2
  exit 1
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_CREATE="${PROJECT_DIR}/bin/create_user.sh"
HOME_CREATE="${HOME}/bin/create_user.sh"

DEFAULT_PASSWORD="TempPass123!"
OS="$(uname -s)"

# Pick the intended script in a strict priority order:
# 1) project ./bin/create_user.sh (required for rubric C4a visibility)
# 2) ~/bin/create_user.sh
pick_create_script() {
  if [[ -x "$PROJECT_CREATE" ]]; then
    echo "$PROJECT_CREATE"
    return 0
  fi
  if [[ -x "$HOME_CREATE" ]]; then
    echo "$HOME_CREATE"
    return 0
  fi
  if command -v create_user.sh >/dev/null 2>&1; then
    command -v create_user.sh
    return 0
  fi
  return 1
}

CREATE_SCRIPT="$(pick_create_script || true)"
[[ -n "$CREATE_SCRIPT" ]] || err "Could not find create_user.sh in ./bin, ~/bin, or PATH"

echo "Demo: create_user.sh requirements"
echo "Detected OS: ${OS}"
echo

echo "Using create_user.sh at:"
echo "  ${CREATE_SCRIPT}"
echo

echo "type -a create_user.sh (for proof of PATH conflicts):"
type -a create_user.sh 2>/dev/null || true
echo

echo "1) Run script without arguments (should error):"
set +e
"$CREATE_SCRIPT"
status=$?
set -e
echo "Exit status: $status"
echo

demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
  demo_username="demo_user_$(date +%s)"
fi

echo "2) Run script with valid arguments (username + password):"
echo "   Username: $demo_username"
echo "   Assigned password: $DEFAULT_PASSWORD"
echo
"$CREATE_SCRIPT" "$demo_username" "$DEFAULT_PASSWORD"
echo

if [[ "$OS" == "Darwin" ]]; then
  echo "3) Switch to the new user (macOS):"
  echo "   Run the following manually in your Panopto recording:"
  echo "   sudo -iu $demo_username whoami"
  echo "   sudo -iu $demo_username id"
  echo
  echo "Note: macOS 'force password change' enforcement may vary by policy."
else
  echo "3) Switch to the new user (Linux):"
  echo "   Expected: system forces password change on first login (chage -d 0 / passwd -e)."
  echo
  if ! command -v su >/dev/null 2>&1; then
    err "su not found; cannot switch users on this system."
  fi
  echo "Run manually in your Panopto recording:"
  echo "   su - $demo_username"
  echo "   (Enter password: $DEFAULT_PASSWORD)"
  echo "After login, exit back:"
  echo "   exit"
fi
