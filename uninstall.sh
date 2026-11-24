#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

echo
echo "VLC 3 - SubMerge Extension Uninstaller"
echo "======================================"
echo

case "$(uname -s)" in
    Linux)
        CANDIDATES=(
            "${XDG_DATA_HOME:-$HOME/.local/share}/vlc/lua/extensions"
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
        echo "ERROR: Unsupported operating system: $(uname -s)"
        exit 1
        ;;
esac

TARGET=""
for DIR in "${CANDIDATES[@]}"; do
    if [[ -d "$DIR" ]]; then
        TARGET="$DIR"
        break
    fi
done

if [[ -z "$TARGET" ]]; then
    echo "ERROR: VLC extensions directory not found."
    echo
    echo "Checked locations:"
    for DIR in "${CANDIDATES[@]}"; do
        echo "  $DIR"
    done
    exit 1
fi

EXTENSION="$TARGET/submerge.lua"
if [[ ! -f "$EXTENSION" ]]; then
    echo "Extension is not installed."
    exit 0
fi

echo "Removing submerge.lua..."
if ! rm -f "$EXTENSION"; then
    echo "ERROR: Failed to remove extension."
    exit 1
fi

echo
echo "SUCCESS: Extension uninstalled!"
echo "Removed: $EXTENSION"
echo
echo "Restart VLC if it is currently running."
