/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem as KWinSystem
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

import "Formatting.js" as Fmt

PlasmoidItem {
    id: root

    readonly property var client: emby
    readonly property var playback: playerController

    // Last connection values applied from the configuration. Keeping these
    // separate from the live client state avoids reconnecting just because the
    // login screen supplied a password that is not stored in the settings.
    property string _appliedServerUrl: ""
    property string _appliedApiKey: ""
    property string _appliedUsername: ""
    property string _appliedPassword: ""
    property bool _keepAboveHelperLoaded: false

    Plasmoid.icon: Qt.resolvedUrl("../icons/emby.svg")
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground
                            | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.status: playerController.currentItem
                     ? PlasmaCore.Types.ActiveStatus
                     : PlasmaCore.Types.PassiveStatus

    switchWidth: Kirigami.Units.gridUnit * 26
    switchHeight: Kirigami.Units.gridUnit * 30

    toolTipMainText: {
        if (playerController.currentItem) {
            return playerController.currentItem.Name || "Emby";
        }
        if (emby.connected) {
            return "Emby" + (emby.serverName ? " · " + emby.serverName : "");
        }
        return "Emby Media";
    }
    toolTipSubText: {
        if (playerController.currentItem) {
            return Fmt.itemSubtitle(playerController.currentItem);
        }
        if (emby.connecting) {
            return "Подключение…";
        }
        if (emby.connected) {
            return "Подключено как " + (emby.userName || "пользователь");
        }
        return "Нажмите, чтобы открыть библиотеку";
    }

    EmbyClient {
        id: emby
    }

    PlaybackController {
        id: playerController
        client: emby
    }

    VideoWindow {
        id: videoWindow
        playback: playerController
    }

    compactRepresentation: Representation {
        client: root.client
        playback: root.playback
        // On a desktop (Planar) the compact representation is the full UI and
        // it is the only video surface while the applet is not expanded.
        videoHostActive: !root.expanded
        onLogoutRequested: root.logout()
    }

    fullRepresentation: FullRepresentation {
        client: root.client
        playback: root.playback
        // Plasma preloads this representation for the popup, so it may own
        // the video sink only while the applet is really expanded.
        videoHostActive: root.expanded
        onLogoutRequested: root.logout()
    }

    function syncConfiguration(forceConnect) {
        var config = Plasmoid.configuration;
        var server = config.serverUrl || "";
        var key = config.apiKey || "";
        var user = config.username || "";
        var password = config.password || "";
        var name = config.deviceName || "Plasma Desktop";
        var connectionChanged = forceConnect
            || root._appliedServerUrl !== server
            || root._appliedApiKey !== key
            || root._appliedUsername !== user
            || root._appliedPassword !== password;

        if (connectionChanged) {
            emby.serverUrl = server;
            emby.apiKey = key;
            emby.username = user;
            emby.password = password;
        }
        emby.deviceName = name;
        emby.deviceId = config.deviceId || "";
        emby.itemLimit = Math.max(50, Number(config.itemLimit) || 300);
        emby.imageSize = Math.max(128, Number(config.imageSize) || 300);

        root._appliedServerUrl = server;
        root._appliedApiKey = key;
        root._appliedUsername = user;
        root._appliedPassword = password;

        playerController.reportProgress = config.reportProgress;

        if (connectionChanged && server.length > 0 && !emby.connecting) {
            emby.token = config.accessToken || "";
            emby.userId = config.userId || "";
            emby.connect();
        }
    }

    function logout() {
        if (playerController) {
            playerController.stop();
        }
        emby.logout();
        Plasmoid.configuration.accessToken = "";
        Plasmoid.configuration.userId = "";
    }

    function saveSession() {
        root._appliedServerUrl = emby.serverUrl;
        Plasmoid.configuration.serverUrl = emby.serverUrl;
        if (emby.apiKey) {
            root._appliedApiKey = emby.apiKey;
            Plasmoid.configuration.apiKey = emby.apiKey;
        }
        Plasmoid.configuration.accessToken = emby.token;
        Plasmoid.configuration.userId = emby.userId;
        Plasmoid.configuration.deviceId = emby.deviceId;
        if (emby.serverName) {
            Plasmoid.configuration.serverName = emby.serverName;
        }
    }

    function ensureVideoOnTop() {
        if (!KWinSystem.KWindowSystem.isPlatformWayland
                || root._keepAboveHelperLoaded) {
            return;
        }
        root._keepAboveHelperLoaded = true;

        var scriptUrl = Qt.resolvedUrl("../code/keep-above.js").toString();
        var scriptPath = decodeURIComponent(scriptUrl.replace(/^file:\/\//, ""));
        var command = "Q=qdbus6; command -v qdbus6 >/dev/null 2>&1 || Q=qdbus; "
            + "$Q org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript '"
            + scriptPath + "' emby-keep-above && "
            + "$Q org.kde.KWin /Scripting org.kde.kwin.Scripting.start";
        kwinCommand.connectSource(command);
    }

    function openVideoWindow() {
        if (!playerController || !playerController.hasVideo) {
            return;
        }
        ensureVideoOnTop();
        playerController.videoPoppedOut = true;
        playerController.videoOutputItem = videoWindow.videoOutputItem;
        videoWindow.show();
        videoWindow.raise();
        videoWindow.requestActivate();
    }

    function focusVideoWindow() {
        if (!playerController || !playerController.hasVideo) {
            return;
        }
        ensureVideoOnTop();
        if (!playerController.videoPoppedOut) {
            playerController.videoPoppedOut = true;
            playerController.videoOutputItem = videoWindow.videoOutputItem;
        }
        videoWindow.show();
        videoWindow.raise();
        videoWindow.requestActivate();
    }

    function embedVideoWindow() {
        videoWindow.hide();
        // Drop the window output first; the visible full representation then
        // attaches its own VideoOutput when videoPoppedOut becomes false.
        if (playerController.videoOutputItem === videoWindow.videoOutputItem) {
            playerController.videoOutputItem = null;
        }
        playerController.videoPoppedOut = false;
        Qt.callLater(function() {
            if (playerController.hasVideo && !playerController.videoOutputItem
                    && playerController.videoHostCount === 0) {
                playerController.stop();
            }
        });
    }

    Component.onCompleted: {
        if (!Plasmoid.configuration.deviceId) {
            Plasmoid.configuration.deviceId = "emby-plasma-"
                + Math.random().toString(36).substring(2, 10)
                + Date.now().toString(36);
        }

        var configuredVolume = Number(Plasmoid.configuration.volume);
        if (isNaN(configuredVolume)) {
            configuredVolume = 70;
        }
        playerController.volume = Math.max(0, Math.min(1, configuredVolume / 100));

        syncConfiguration(true);
    }

    onExpandedChanged: {
        if (root.expanded) {
            syncConfiguration(false);
        }
    }

    Connections {
        target: emby

        function onLoginSucceeded() {
            root.saveSession();
        }

        function onDeviceIdChanged() {
            if (emby.deviceId) {
                Plasmoid.configuration.deviceId = emby.deviceId;
            }
        }

        function onServerNameChanged() {
            if (emby.serverName) {
                Plasmoid.configuration.serverName = emby.serverName;
            }
        }
    }

    Connections {
        target: playerController

        function onVideoStarted() {
            if (playerController.videoPoppedOut) {
                root.openVideoWindow();
            }
        }

        function onTrackChanged() {
            if (!playerController.hasVideo) {
                videoWindow.hide();
                playerController.videoPoppedOut = false;
            } else if (playerController.videoPoppedOut) {
                root.openVideoWindow();
            }
        }

        function onVideoStopped() {
            videoWindow.hide();
            playerController.videoPoppedOut = false;
        }

        function onVideoPopOutRequested() {
            root.openVideoWindow();
        }

        function onVideoEmbedRequested() {
            root.embedVideoWindow();
        }

        function onVideoFocusRequested() {
            root.focusVideoWindow();
        }

        function onVolumeChanged() {
            volumeSaveTimer.restart();
        }
    }

    Timer {
        id: volumeSaveTimer
        interval: 500
        onTriggered: Plasmoid.configuration.volume =
                     Math.round(playerController.volume * 100)
    }

    P5Support.DataSource {
        id: kwinCommand
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source);
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onValueChanged(key, value) {
            if (key === "serverUrl" || key === "apiKey"
                    || key === "username" || key === "password") {
                root.syncConfiguration(false);
            } else if (key === "reportProgress") {
                playerController.reportProgress = value;
            } else if (key === "itemLimit") {
                emby.itemLimit = Math.max(50, Number(value) || 300);
            } else if (key === "imageSize") {
                emby.imageSize = Math.max(128, Number(value) || 300);
            } else if (key === "volume" && !playerController.currentItem) {
                playerController.setVolume((Number(value) || 0) / 100);
            }
        }
    }
}
