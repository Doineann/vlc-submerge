#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

echo
echo "VLC 3 - SubMerge Extension Installer"
echo "===================================="
echo

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/submerge.lua"

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: submerge.lua not found in installer directory."
    exit 1
fi

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
    ROOT="${DIR%/lua/extensions}"
    if [[ -d "$ROOT" ]]; then
        TARGET="$DIR"
        break
    fi
done

if [[ -z "$TARGET" ]]; then
    echo "ERROR: VLC data directory not found."
    echo "No directories were created."
    echo
    echo "Checked locations:"
    for DIR in "${CANDIDATES[@]}"; do
        echo "  ${DIR%/lua/extensions}"
    done
    echo
    echo "Please install VLC 3 and run VLC at least once."
    exit 1
fi

if ! mkdir -p "$TARGET"; then
    echo "ERROR: Failed to create extensions directory: $TARGET"
    exit 1
fi

EXTENSION="$TARGET/submerge.lua"
echo "Installing submerge.lua..."
if ! cp -f "$SOURCE" "$EXTENSION"; then
    echo "ERROR: Failed to copy extension."
    exit 1
fi

if ! chmod 644 "$EXTENSION"; then
    echo "ERROR: Failed to set permissions on extension."
    exit 1
fi

echo
echo "SUCCESS: Extension installed!"
echo "Location: $EXTENSION"
echo
echo "Restart VLC to load the extension."
