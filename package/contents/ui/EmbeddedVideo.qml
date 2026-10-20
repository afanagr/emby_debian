/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtMultimedia

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "Formatting.js" as Fmt

/*
 * Video surface embedded into the widget. The actual VideoOutput is owned by
 * this item; the playout controller attaches it while the video is not in the
 * separate always-on-top window.
 */
Item {
    id: root

    property var playback: null

    property alias videoOutputItem: videoOut

    readonly property var item: playback ? playback.currentItem : null
    readonly property bool poppedOut: playback ? playback.videoPoppedOut : false

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: !root.poppedOut
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit * 2,
                        Kirigami.Units.gridUnit * 20)
        visible: root.poppedOut
        spacing: Kirigami.Units.smallSpacing

        PC3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Видео открыто в отдельном окне"
            font.weight: Font.DemiBold
        }

        PC3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.item ? (root.item.Name || "") : ""
            opacity: 0.7
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            PC3.Button {
                icon.name: "video-x-generic"
                text: "Показать окно"
                onClicked: if (root.playback) root.playback.requestVideoFocus()
            }

            PC3.Button {
                icon.name: "view-restore"
                text: "Вернуть в виджет"
                onClicked: if (root.playback) root.playback.requestVideoEmbed()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.poppedOut
        onClicked: clickTimer.restart()
        onDoubleClicked: {
            clickTimer.stop();
            if (root.playback) {
                root.playback.requestVideoPopOut();
            }
        }

        Timer {
            id: clickTimer
            interval: 220
            onTriggered: if (root.playback) root.playback.togglePlayPause()
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: videoControls.implicitHeight + Kirigami.Units.smallSpacing * 2
        visible: !root.poppedOut
        color: Qt.rgba(0, 0, 0, 0.62)

        RowLayout {
            id: videoControls
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PC3.ToolButton {
                icon.name: root.playback && root.playback.playing
                           ? "media-playback-pause" : "media-playback-start"
                onClicked: if (root.playback) root.playback.togglePlayPause()
            }

            PC3.ToolButton {
                icon.name: "media-skip-backward"
                onClicked: if (root.playback) root.playback.previous()
            }

            PC3.ToolButton {
                icon.name: "media-skip-forward"
                onClicked: if (root.playback) root.playback.next()
            }

            PC3.Label {
                Layout.fillWidth: true
                text: root.item ? (root.item.Name || "") : ""
                color: "white"
                elide: Text.ElideRight
                maximumLineCount: 1
                font.weight: Font.DemiBold
            }

            PC3.Label {
                text: root.playback ? Fmt.formatMs(root.playback.positionMs) : "0:00"
                color: "white"
                opacity: 0.85
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PC3.Label {
                text: "/"
                color: "white"
                opacity: 0.55
            }

            PC3.Label {
                text: root.playback ? Fmt.formatMs(root.playback.durationMs) : "0:00"
                color: "white"
                opacity: 0.85
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            ToolTipButton {
                icon.name: "window-new"
                onClicked: if (root.playback) root.playback.requestVideoPopOut()
                tooltip: "Открыть в отдельном окне поверх других"
            }
        }
    }
}
