#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

echo
echo "VLC 3 - Submerge Extension Installer"
echo "===================================="
echo

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/submerge.lua"

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: submerge.lua not found in installer directory."
    exit 1
fi

OS="$(uname -s)"
TARGET=""

case "$OS" in
    Linux)
        XDG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

        CANDIDATES=(
            "$XDG_DIR/vlc/lua/extensions"
            "$HOME/.vlc/lua/extensions"
        )
        ;;

    Darwin)
        CANDIDATES=(
            "$HOME/Library/Application Support/org.videolan.vlc/lua/extensions"
            "$HOME/.vlc/lua/extensions"
        )
        ;;

    *)
        echo "ERROR: Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Find the first existing extensions directory.
for DIR in "${CANDIDATES[@]}"; do
    if [[ -d "$DIR" ]]; then
        TARGET="$DIR"
        break
    fi
done

if [[ -z "$TARGET" ]]; then
    echo "ERROR: VLC extensions directory not found."
    echo "No directories were created."
    echo
    echo "Checked locations:"
    for DIR in "${CANDIDATES[@]}"; do
        echo "  $DIR"
    done
    echo
    echo "Please install VLC 3 and run VLC at least once."
    exit 1
fi

echo "Installing submerge.lua..."
if ! cp -f "$SOURCE" "$TARGET/submerge.lua"; then
    echo "ERROR: Failed to copy extension."
    exit 1
fi

echo
echo "SUCCESS: Extension installed!"
echo "Location: $TARGET/submerge.lua"
echo
echo "Restart VLC to load the extension."

exit 0
