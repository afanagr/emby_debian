#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Emby Plasma contributors
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

PLUGIN_ID="org.kde.plasma.emby"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 не найден. Установите пакет kpackagetool6." >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -Fqx "$PLUGIN_ID"; then
    kpackagetool6 --type Plasma/Applet --remove "$PLUGIN_ID"
    echo "Виджет $PLUGIN_ID удалён."
else
    echo "Виджет $PLUGIN_ID не установлен."
fi
