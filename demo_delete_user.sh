#!/usr/bin/env bash
# demo_delete_user.sh — WGU D796 RQN1 Task 1 (B5 demo)
#
# a1: Demonstrate `delete_user.sh` behavior and collect rubric evidence.
# a2: Prefer the project copy in `./bin` to avoid PATH conflicts with other installations.
# a3: Run three scenarios: missing args, valid deletion, and a failed switch to the deleted user.

set -euo pipefail  # a4: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
  echo "Error: $*" >&2
  exit 1
}

# a5: Resolve absolute project directory and expected script locations.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DELETE="${PROJECT_DIR}/bin/delete_user.sh"
PROJECT_CREATE="${PROJECT_DIR}/bin/create_user.sh"

HOME_DELETE="${HOME}/bin/delete_user.sh"
HOME_CREATE="${HOME}/bin/create_user.sh"

DEFAULT_PASSWORD="TempPass123!"
OS="$(uname -s)"

# f2: pick_script — Select a script path with strict priority: project `./bin`, `~/bin`, then PATH.
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

# a6: Select the intended script paths using the priority order defined above.
DELETE_SCRIPT="$(pick_script "$PROJECT_DELETE" "$HOME_DELETE" "delete_user.sh" || true)"
CREATE_SCRIPT="$(pick_script "$PROJECT_CREATE" "$HOME_CREATE" "create_user.sh" || true)"

[[ -n "$DELETE_SCRIPT" ]] || err "Could not find delete_user.sh in ./bin, ~/bin, or PATH"
[[ -n "$CREATE_SCRIPT" ]] || err "Could not find create_user.sh in ./bin, ~/bin, or PATH"

# a7: Print environment detection and script resolution evidence (PATH conflict proof).
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

# a8: Scenario 1 — run without arguments to demonstrate usage/error handling.
echo "1) Run delete script without arguments (should error):"
set +e
"$DELETE_SCRIPT"
status=$?
set -e
echo "Exit status: $status"
echo

# a9: When no username arg is provided, create a temporary user to demonstrate deletion.
demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
  demo_username="demo_user_$(date +%s)"
  echo "No username provided. Creating a temporary user to delete: $demo_username"
  echo "Assigned password: $DEFAULT_PASSWORD"
  echo
  "$CREATE_SCRIPT" "$demo_username" "$DEFAULT_PASSWORD"
  echo
fi

# a10: Scenario 2 — run with a valid username to delete the account (confirmation prompt expected).
echo "2) Run delete script with valid arguments (username):"
echo "   Username: $demo_username"
echo "   A confirmation prompt is expected before deletion."
echo
"$DELETE_SCRIPT" "$demo_username"
echo

# a11: Scenario 3 — attempt to switch to the deleted user; success indicates deletion did not occur.
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

# a12: Emit a final pass/fail message based on whether the switch succeeded.
if [[ $status -eq 0 ]]; then
  echo "Unexpected: switch succeeded (user may not have been deleted)."
else
  echo "As expected, switching to $demo_username failed."
fi
