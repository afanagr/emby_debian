/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: compact

    property var client: null
    property var playback: null

    readonly property var item: playback ? playback.currentItem : null
    readonly property string artwork: client && item ? client.imageUrl(item, 256) : ""
    readonly property bool planar: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool hasArtwork: cover.status === Image.Ready
    readonly property real progress: {
        if (!playback || !playback.currentItem || playback.durationMs <= 0) {
            return 0;
        }
        return Math.max(0, Math.min(1, playback.positionMs / playback.durationMs));
    }

    Layout.minimumWidth: Kirigami.Units.iconSizes.medium
    Layout.minimumHeight: Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
    Layout.preferredHeight: Kirigami.Units.iconSizes.medium

    Image {
        id: cover
        anchors.fill: parent
        source: compact.artwork
        visible: status === Image.Ready
        asynchronous: true
        cache: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit)
        visible: !compact.hasArtwork && compact.planar
        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(Kirigami.Units.gridUnit * 5,
                                            compact.height * 0.35)
            Layout.preferredHeight: Layout.preferredWidth
            source: Qt.resolvedUrl("../icons/emby.svg")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Emby"
            color: Kirigami.Theme.textColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: compact.item ? "Обложка недоступна" : "Открыть библиотеку"
            color: Kirigami.Theme.textColor
            opacity: 0.65
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }

    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.8
        height: width
        visible: !compact.hasArtwork && !compact.planar
        source: Qt.resolvedUrl("../icons/emby.svg")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: info.implicitHeight + Kirigami.Units.smallSpacing * 2
        visible: compact.planar && compact.item !== null
        color: Qt.rgba(0, 0, 0, 0.58)

        ColumnLayout {
            id: info
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: compact.item ? (compact.item.Name || "") : ""
                color: "white"
                elide: Text.ElideRight
                maximumLineCount: 1
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: compact.item && compact.item.Album ? compact.item.Album : ""
                color: "white"
                opacity: 0.75
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text.length > 0
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    Kirigami.Icon {
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(12, Math.min(parent.width, parent.height) / 4)
        height: width
        visible: compact.item !== null && compact.playback && !compact.playback.playing
        source: "media-playback-pause"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 2
        width: parent.width * compact.progress
        color: Kirigami.Theme.highlightColor
        visible: compact.item !== null && compact.progress > 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton && compact.playback) {
                compact.playback.togglePlayPause();
            } else {
                // Ask the shell to open/close the popup. Plasmoid is the
                // Plasma::Applet here and has no "expanded" property.
                Plasmoid.activated();
            }
        }

        onWheel: function(wheel) {
            if (!compact.playback) {
                return;
            }
            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            compact.playback.setVolume(compact.playback.volume + step);
        }
    }
}
