#!/usr/bin/env bash

# I use strict mode so setup steps stop if something important fails.
set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

# I use the script location as the project root so file paths are predictable.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/bin"
ALIAS_SRC="${SCRIPT_DIR}/bash_aliases"
ALIAS_DEST="${HOME}/.bash_aliases"
BASHRC="${HOME}/.bashrc"
BASH_PROFILE="${HOME}/.bash_profile"
BASHRC_MARKER="# Added by setup_shell_env.sh"

mkdir -p "$BIN_DIR"

# I copy the user scripts into ~/bin so they are on PATH without removing the project copies.
for script in create_user.sh delete_user.sh; do
    if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
        cp "${SCRIPT_DIR}/${script}" "${BIN_DIR}/${script}"
    else
        err "Required script not found: $script"
    fi
    chmod +x "${BIN_DIR}/${script}"
done

# Install the alias file as a separate file in the home directory.
if [[ -f "$ALIAS_SRC" ]]; then
    cp "$ALIAS_SRC" "$ALIAS_DEST"
else
    err "Alias template not found: $ALIAS_SRC"
fi

# Ensure ~/.bashrc exists so I can safely append to it.
touch "$BASHRC"

# Append prompt/alias/path settings once, guarded by a marker.
if ! grep -qF "$BASHRC_MARKER" "$BASHRC"; then
    cat <<EOF >> "$BASHRC"

$BASHRC_MARKER
# I set a colored $ prompt and set my input text to a different color.
export PS1="\\[\\e[1;32m\\]$\\[\\e[0;36m\\] "
# I reset colors before command output so only the prompt/input are colored.
export PS0="\\[\\e[0m\\]"
# I keep aliases in a separate file so I can edit them without touching .bashrc.
if [[ -f "\$HOME/.bash_aliases" ]]; then
  . "\$HOME/.bash_aliases"
fi
# I add ~/bin so create_user.sh and delete_user.sh run from any directory.
export PATH="\$HOME/bin:\$PATH"
EOF
fi

# Ensure login shells source .bashrc so the prompt/aliases apply after login.
if [[ -f "$BASH_PROFILE" ]]; then
    if ! grep -qF ".bashrc" "$BASH_PROFILE"; then
        cat <<'EOF' >> "$BASH_PROFILE"

# I source .bashrc so login shells pick up my interactive settings.
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
    fi
else
    cat <<'EOF' > "$BASH_PROFILE"
# I source .bashrc so login shells pick up my interactive settings.
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
fi

echo "Applying changes with: source $BASHRC"
# shellcheck disable=SC1090
set +e
source "$BASHRC"
source_status=$?
set -e
echo "source exit status: $source_status"
echo

echo "Verification: PS1 is now set to:"
echo "$PS1"
echo

set +e
echo "Verification: aliases from $ALIAS_DEST"
alias lrt
alias la
alias cls
alias lslrt
alias lsa
alias clr
alias cddesktop
alias cddownload
alias cddocuments
alias desktop
alias download
alias documents
alias cddownloads
echo

echo "Verification: PATH includes $BIN_DIR"
command -v create_user.sh
command -v delete_user.sh
echo
set -e

echo "Demonstration: run scripts from /tmp (no args, expect usage errors):"
set +e
(
    cd /tmp || exit 1
    create_user.sh
    echo "create_user.sh exit status: $?"
    delete_user.sh
    echo "delete_user.sh exit status: $?"
)
set -e
