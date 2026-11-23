#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the full SubMerge test suite.
# Usage: ./run_tests.sh

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v luajit >/dev/null 2>&1; then
    echo "ERROR: luajit not found. Install LuaJIT to run the tests." >&2
    exit 1
fi

exec luajit tests/test_runner.lua
