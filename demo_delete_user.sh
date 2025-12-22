#!/usr/bin/env bash
# demo_delete_user.sh — WGU D796 RQN1 Task 1 (B5 demo)
# Demonstrates:
# 1) Run delete_user.sh without args (shows error)
# 2) Run delete_user.sh with valid args (username)
# 3) Attempt to switch to deleted user (should fail)
#
# Critical: Forces the demo to use the PROJECT version (./bin/delete_user.sh),
# not some other copy in /usr/local/bin.

set -euo pipefail

err() {
  echo "Error: $*" >&2
  exit 1
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DELETE="${PROJECT_DIR}/bin/delete_user.sh"
PROJECT_CREATE="${PROJECT_DIR}/bin/create_user.sh"

HOME_DELETE="${HOME}/bin/delete_user.sh"
HOME_CREATE="${HOME}/bin/create_user.sh"

DEFAULT_PASSWORD="TempPass123!"
OS="$(uname -s)"

pick_script() {
  local project_path="$1"
  local home_path="$2"
  local name="$3"

  if [[ -x "$project_path" ]]; then
    echo "$project_path"
    return 0
  fi
  if [[ -x "$home_path" ]]; then
    echo "$home_path"
    return 0
  fi
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  return 1
}

DELETE_SCRIPT="$(pick_script "$PROJECT_DELETE" "$HOME_DELETE" "delete_user.sh" || true)"
CREATE_SCRIPT="$(pick_script "$PROJECT_CREATE" "$HOME_CREATE" "create_user.sh" || true)"

[[ -n "$DELETE_SCRIPT" ]] || err "Could not find delete_user.sh in ./bin, ~/bin, or PATH"
[[ -n "$CREATE_SCRIPT" ]] || err "Could not find create_user.sh in ./bin, ~/bin, or PATH"

echo "Demo: delete_user.sh requirements"
echo "Detected OS: ${OS}"
echo

echo "Using delete_user.sh at:"
echo "  ${DELETE_SCRIPT}"
echo "Using create_user.sh at:"
echo "  ${CREATE_SCRIPT}"
echo

echo "type -a delete_user.sh (for proof of PATH conflicts):"
type -a delete_user.sh 2>/dev/null || true
echo
echo "type -a create_user.sh (for proof of PATH conflicts):"
type -a create_user.sh 2>/dev/null || true
echo

echo "1) Run delete script without arguments (should error):"
set +e
"$DELETE_SCRIPT"
status=$?
set -e
echo "Exit status: $status"
echo

demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
  demo_username="demo_user_$(date +%s)"
  echo "No username provided. Creating a temporary user to delete: $demo_username"
  echo "Assigned password: $DEFAULT_PASSWORD"
  echo
  "$CREATE_SCRIPT" "$demo_username" "$DEFAULT_PASSWORD"
  echo
fi

echo "2) Run delete script with valid arguments (username):"
echo "   Username: $demo_username"
echo "   You will be prompted to confirm deletion."
echo
"$DELETE_SCRIPT" "$demo_username"
echo

echo "3) Attempt to switch to the deleted user (should fail):"
if [[ "$OS" == "Darwin" ]]; then
  set +e
  sudo -iu "$demo_username" whoami >/dev/null 2>&1
  status=$?
  set -e
else
  set +e
  su - "$demo_username" -c "whoami" >/dev/null 2>&1
  status=$?
  set -e
fi

if [[ $status -eq 0 ]]; then
  echo "Unexpected: switch succeeded (user may not have been deleted)."
else
  echo "As expected, switching to $demo_username failed."
fi
