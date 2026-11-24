#!/bin/sh
# Copy this addon into the WoW Forever AddOns folder (macOS default install path).
# Only touches AddOns/StrangerBuff. Pass a different AddOns path as the first argument if needed.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
ADDONS="${1:-/Applications/World of Warcraft/_forever_/Interface/AddOns}"
DEST="$ADDONS/StrangerBuff"
mkdir -p "$DEST"
rsync -a --delete --exclude '.git' --exclude '.gitignore' --exclude '.DS_Store' --exclude 'install.sh' "$SRC/" "$DEST/"
echo "Installed StrangerBuff to $DEST"
