#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Emby Plasma contributors
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

# Qt's QML XMLHttpRequest and Qt Multimedia use the http_proxy/https_proxy
# environment variables, but plasmashell is started by systemd and does not
# inherit the proxy settings of an interactive shell. This helper creates a
# user service drop-in so that Emby (and media streams) can be reached through
# a local HTTP proxy such as Xray/Happ.
#
# Usage:
#   ./setup-plasmashell-proxy.sh http://127.0.0.1:10808
#   ./setup-plasmashell-proxy.sh --remove

SERVICE_DIR="$HOME/.config/systemd/user/plasma-plasmashell.service.d"
CONFIG_FILE="$SERVICE_DIR/proxy.conf"

if [ "${1:-}" = "--remove" ]; then
    rm -f "$CONFIG_FILE"
    systemctl --user daemon-reload
    systemctl --user restart plasma-plasmashell.service
    echo "Прокси для plasmashell удалён."
    exit 0
fi

PROXY="${1:-http://127.0.0.1:10808}"
NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"

mkdir -p "$SERVICE_DIR"
cat > "$CONFIG_FILE" <<EOF
[Service]
Environment="http_proxy=$PROXY"
Environment="https_proxy=$PROXY"
Environment="all_proxy=$PROXY"
Environment="no_proxy=$NO_PROXY"
EOF

systemctl --user daemon-reload
systemctl --user restart plasma-plasmashell.service

echo "Прокси $PROXY настроен для plasmashell."
echo "Файл: $CONFIG_FILE"
echo "Удалить: $0 --remove"
