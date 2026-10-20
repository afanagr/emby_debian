#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Emby Plasma contributors
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

# Basic checks that can be run before committing. Requires qmllint from
# qt6-declarative-dev-tools; validates the KPackage structure if
# kpackagetool6 is available.
#
# Usage: ./scripts/check.sh

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$REPO_DIR/package"
QML_DIR="$PACKAGE_DIR/contents/ui"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

QMLLINT="$(command -v qmllint || true)"
if [ -z "$QMLLINT" ] && [ -x /usr/lib/qt6/bin/qmllint ]; then
    QMLLINT=/usr/lib/qt6/bin/qmllint
fi

if [ -n "$QMLLINT" ]; then
    # --bare only parses the files: Plasma QML modules are registered by
    # plasmashell at runtime and are not visible to a standalone qmllint.
    if ! "$QMLLINT" --bare "$QML_DIR"/*.qml >"$TEMP_DIR/qmllint.log" 2>&1; then
        cat "$TEMP_DIR/qmllint.log" >&2
        exit 1
    fi
    echo "QML syntax: OK"
else
    echo "qmllint не найден. Установите пакет qt6-declarative-dev-tools." >&2
    exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1 \
        && kpackagetool6 --type Plasma/Applet --list >/dev/null 2>&1; then
    mkdir -p "$TEMP_DIR/plasmoids"
    kpackagetool6 --type Plasma/Applet --packageroot "$TEMP_DIR/plasmoids" \
        --install "$PACKAGE_DIR" >/dev/null
    echo "KPackage structure: OK"
else
    echo "Структура Plasma/Applet недоступна (нужен plasma-desktoptheme);" \
         "проверка пакета пропущена." >&2
fi

echo "All checks passed."
