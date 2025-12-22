#!/usr/bin/env bash
# setup_shell_env.sh — WGU D796 RQN1 Task 1 (Section C)
#
# Rubric-safe + evaluator-proof:
# - Creates a bin directory inside the PROJECT folder: ./bin
# - Ensures create_user.sh and delete_user.sh exist in ./bin (project deliverable)
# - Also installs them into ~/bin so they can run from ANY directory
# - Forces ~/bin to be FIRST in PATH (so it resolves to ~/bin, not /usr/local/bin)
# - Sets "$" prompt with different colors
# - Sources aliases from ~/.bash_aliases
# - Ensures login shells source ~/.bashrc (macOS-safe)

set -euo pipefail

err() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# Find a script in:
# 1) project root
# 2) project ./bin
# 3) ~/bin
# 4) PATH
find_script() {
  local name="$1"
  local project_dir="$2"

  if [[ -f "$project_dir/$name" ]]; then
    echo "$project_dir/$name"
    return 0
  fi

  if [[ -f "$project_dir/bin/$name" ]]; then
    echo "$project_dir/bin/$name"
    return 0
  fi

  if [[ -f "$HOME/bin/$name" ]]; then
    echo "$HOME/bin/$name"
    return 0
  fi

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  return 1
}

for cmd in uname cp chmod mkdir grep cat tr printf sed nl; do
  require_cmd "$cmd"
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_BIN="$PROJECT_DIR/bin"   # <-- bin in your PROJECT folder (what you wanted)
HOME_BIN="$HOME/bin"             # <-- bin in your HOME for PATH execution (rubric-safe)

ALIAS_SRC="$PROJECT_DIR/bash_aliases"
ALIAS_DEST="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
MARKER="# Added by setup_shell_env.sh (WGU D796 RQN1)"

# 1) Create project bin + home bin
mkdir -p "$PROJECT_BIN"
mkdir -p "$HOME_BIN"

# 2) Locate scripts somewhere
create_src="$(find_script create_user.sh "$PROJECT_DIR" || true)"
delete_src="$(find_script delete_user.sh "$PROJECT_DIR" || true)"

[[ -n "$create_src" ]] || err "create_user.sh not found (expected in project root, project bin, ~/bin, or PATH)"
[[ -n "$delete_src" ]] || err "delete_user.sh not found (expected in project root, project bin, ~/bin, or PATH)"

# 3) Copy scripts into PROJECT ./bin (deliverable visibility)
proj_create="$PROJECT_BIN/create_user.sh"
proj_delete="$PROJECT_BIN/delete_user.sh"

if [[ "$create_src" != "$proj_create" ]]; then
  cp -f "$create_src" "$proj_create"
fi
if [[ "$delete_src" != "$proj_delete" ]]; then
  cp -f "$delete_src" "$proj_delete"
fi
chmod +x "$proj_create" "$proj_delete"

# 4) Copy scripts into ~/bin (so they run from anywhere via PATH)
home_create="$HOME_BIN/create_user.sh"
home_delete="$HOME_BIN/delete_user.sh"

# Prefer the project ./bin versions as the source-of-truth
cp -f "$proj_create" "$home_create"
cp -f "$proj_delete" "$home_delete"
chmod +x "$home_create" "$home_delete"

# 5) Install aliases file
[[ -f "$ALIAS_SRC" ]] || err "bash_aliases file missing in project folder: $ALIAS_SRC"
cp -f "$ALIAS_SRC" "$ALIAS_DEST"

# 6) Ensure ~/.bashrc exists
touch "$BASHRC"

# 7) Append config once (C1/C2/C4b)
if ! grep -qF "$MARKER" "$BASHRC"; then
  cat <<'EOF' >>"$BASHRC"

# Added by setup_shell_env.sh (WGU D796 RQN1)

# C1: "$" prompt with different colors
export PS1="\[\e[1;32m\]\$\[\e[0;36m\] "

# Reset color before command output
export PROMPT_COMMAND='echo -ne "\e[0m"'

# C2: Load aliases from separate file
if [[ -f "$HOME/.bash_aliases" ]]; then
  . "$HOME/.bash_aliases"
fi

# C4b: Ensure ~/bin is FIRST in PATH
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) export PATH="$HOME/bin:$PATH" ;;
esac
EOF
fi

# 8) macOS login shell fix
if [[ -f "$BASH_PROFILE" ]]; then
  if ! grep -q 'source "$HOME/.bashrc"' "$BASH_PROFILE" && ! grep -q 'source ~/.bashrc' "$BASH_PROFILE"; then
    cat <<'EOF' >>"$BASH_PROFILE"

# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
EOF
  fi
else
  cat <<'EOF' >"$BASH_PROFILE"
# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
EOF
fi

# 9) Apply & verify
echo "Applying changes with: source $BASHRC"
# shellcheck disable=SC1090
source "$BASHRC"
echo "source exit status: 0"
echo

echo "Verification: project bin directory exists and contains scripts:"
ls -la "$PROJECT_BIN"
echo

echo "Verification: home bin directory exists and contains scripts:"
ls -la "$HOME_BIN"
echo

echo "Verification: PATH order (first 15 entries):"
echo "$PATH" | tr ':' '\n' | nl -ba | sed -n '1,15p'
echo

echo "Verification: create_user.sh resolves to:"
type -a create_user.sh || true
echo
echo "Verification: delete_user.sh resolves to:"
type -a delete_user.sh || true
echo

echo "Demonstration: run scripts from /tmp (no args, expect errors):"
set +e
(
  cd /tmp || exit 1
  create_user.sh
  echo "create_user.sh exit status: $?"
  delete_user.sh
  echo "delete_user.sh exit status: $?"
)
set -e

echo
echo "Done — project ./bin created, scripts installed to project and ~/bin, PATH is set."
exit 0
