/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: login

    property var client: null
    property string localError: ""

    readonly property string message: {
        if (localError.length > 0) {
            return localError;
        }
        return client && client.lastError ? client.lastError : "";
    }

    function submit() {
        if (!client || client.connecting) {
            return;
        }

        localError = "";
        var url = serverField.text.trim();
        if (url.length === 0) {
            localError = "Укажите адрес сервера Emby";
            return;
        }

        var key = "";
        if (useApiKey.checked) {
            key = apiKeyField.text.trim();
            if (key.length === 0) {
                localError = "Введите API-ключ";
                return;
            }
        }

        var user = usernameField.text.trim();
        if (user.length === 0 && client.username) {
            user = client.username;
        }
        var pass = passwordField.text;
        if (pass.length === 0 && client.password) {
            pass = client.password;
        }
        if (!useApiKey.checked) {
            if (user.length === 0) {
                localError = "Введите имя пользователя";
                return;
            }
            if (pass.length === 0) {
                localError = "Введите пароль";
                return;
            }
        }

        client.serverUrl = url;
        client.apiKey = key;
        client.username = user;
        client.password = pass;
        client.token = "";
        client.userId = "";
        client.connect();
    }

    Component.onCompleted: {
        if (!client) {
            return;
        }
        serverField.text = client.serverUrl || "";
        usernameField.text = client.username || "";
        if (client.apiKey) {
            useApiKey.checked = true;
            apiKeyField.text = client.apiKey;
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: form.height + Kirigami.Units.gridUnit * 2
        clip: true

        ColumnLayout {
            id: form
            width: Math.min(flick.width - Kirigami.Units.gridUnit * 2,
                            Kirigami.Units.gridUnit * 24)
            x: (flick.width - width) / 2
            y: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                source: Qt.resolvedUrl("../icons/emby.svg")
            }

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 2
                horizontalAlignment: Text.AlignHCenter
                text: "Подключение к Emby"
            }

            PC3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.7
                text: "Введите адрес медиасервера Emby. Библиотека, музыка и видео останутся на сервере."
            }

            PC3.Label {
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "Адрес сервера"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PC3.TextField {
                id: serverField
                Layout.fillWidth: true
                placeholderText: "http://192.168.1.10:8096"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                onAccepted: login.submit()
            }

            PC3.CheckBox {
                id: useApiKey
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "Использовать API-ключ"
            }

            PlasmaExtras.PasswordField {
                id: apiKeyField
                Layout.fillWidth: true
                visible: useApiKey.checked
                placeholderText: "API-ключ Emby"
                onAccepted: login.submit()
            }

            PC3.Label {
                Layout.topMargin: useApiKey.checked ? 0 : Kirigami.Units.smallSpacing
                visible: !useApiKey.checked
                text: "Имя пользователя"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PC3.TextField {
                id: usernameField
                Layout.fillWidth: true
                visible: !useApiKey.checked
                placeholderText: "Пользователь Emby"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: login.submit()
            }

            PC3.Label {
                visible: !useApiKey.checked
                text: "Пароль"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PlasmaExtras.PasswordField {
                id: passwordField
                Layout.fillWidth: true
                visible: !useApiKey.checked
                placeholderText: "Пароль"
                onAccepted: login.submit()
            }

            PC3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: login.message.length > 0
                wrapMode: Text.Wrap
                color: Kirigami.Theme.negativeTextColor
                text: login.message
            }

            PC3.Button {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                icon.name: "network-connect"
                text: client && client.connecting ? "Подключение…" : "Подключиться"
                enabled: client && !client.connecting
                onClicked: login.submit()
            }

            PC3.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: client && client.connecting
                visible: running
            }

            PC3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                wrapMode: Text.Wrap
                opacity: 0.55
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: "Пароль, введённый здесь, не сохраняется. Для автоматического входа "
                      + "используйте API-ключ или заполните данные в настройках виджета."
            }
        }
    }
}
