/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * Album/poster image with a themed placeholder while the image is loading or
 * when an item has no artwork.
 */

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: art

    property string source: ""
    property string fallbackIcon: "media-playback-start"

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.alternateBackgroundColor
        visible: image.status !== Image.Ready

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.max(Kirigami.Units.iconSizes.small,
                            Math.min(parent.width, parent.height) * 0.45)
            height: width
            source: art.fallbackIcon
            opacity: 0.55
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: art.source
        visible: status === Image.Ready
        asynchronous: true
        cache: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(height)))
    }

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, 0.12)
    }
}
