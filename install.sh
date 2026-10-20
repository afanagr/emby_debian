#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Emby Plasma contributors
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

PLUGIN_ID="org.kde.plasma.emby"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 не найден. Установите пакет kpackagetool6." >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -Fqx "$PLUGIN_ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_DIR"
    echo "Виджет $PLUGIN_ID обновлён."
else
    kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"
    echo "Виджет $PLUGIN_ID установлен."
fi

echo
echo "Перезапустите Plasma, чтобы обновить список виджетов:"
echo "  systemctl --user restart plasma-plasmashell.service"
echo "Затем: правый клик по панели или рабочему столу → «Добавить виджеты» → Emby."
echo
echo "Если Emby доступен только через локальный прокси:"
echo "  ./setup-plasmashell-proxy.sh http://127.0.0.1:10808"
