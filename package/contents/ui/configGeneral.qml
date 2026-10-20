/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_serverUrl: serverUrlField.text
    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_deviceName: deviceNameField.text
    property alias cfg_volume: volumeSpin.value
    property alias cfg_reportProgress: reportProgressCheck.checked
    property alias cfg_itemLimit: itemLimitSpin.value
    property alias cfg_imageSize: imageSizeSpin.value

    // Session values are written by the applet itself. They are exposed here
    // so that opening and applying the settings dialog does not lose them.
    property string cfg_accessToken
    property string cfg_userId
    property string cfg_serverName
    property string cfg_deviceId

    Kirigami.FormLayout {
        QQC2.TextField {
            id: serverUrlField
            Kirigami.FormData.label: "Адрес сервера:"
            placeholderText: "http://192.168.1.10:8096"
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: "API-ключ:"
            placeholderText: "Рекомендуется для постоянного входа"
            echoMode: TextInput.Password
        }

        QQC2.TextField {
            id: usernameField
            Kirigami.FormData.label: "Пользователь:"
            placeholderText: "Имя пользователя Emby"
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
        }

        QQC2.TextField {
            id: passwordField
            Kirigami.FormData.label: "Пароль:"
            placeholderText: "Необязательно, если указан API-ключ"
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                       | Qt.ImhSensitiveData
        }

        QQC2.TextField {
            id: deviceNameField
            Kirigami.FormData.label: "Имя устройства:"
            placeholderText: "Plasma Desktop"
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: volumeSpin
            Kirigami.FormData.label: "Громкость по умолчанию:"
            from: 0
            to: 100
            stepSize: 5
            editable: true
        }

        QQC2.CheckBox {
            id: reportProgressCheck
            Kirigami.FormData.label: "Прогресс:"
            text: "Отправлять позицию и отметку о просмотре на сервер"
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: itemLimitSpin
            Kirigami.FormData.label: "Элементов на страницу:"
            from: 50
            to: 2000
            stepSize: 50
            editable: true
        }

        QQC2.SpinBox {
            id: imageSizeSpin
            Kirigami.FormData.label: "Размер обложек, px:"
            from: 128
            to: 1200
            stepSize: 64
            editable: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Войти можно и прямо в виджете. После успешного входа токен "
                  + "сохраняется автоматически. Пароль в настройках хранится в "
                  + "открытом виде в конфигурации KDE — для постоянного доступа "
                  + "лучше использовать API-ключ Emby."
        }
    }
}
