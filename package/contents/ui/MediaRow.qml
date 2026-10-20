/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "Formatting.js" as Fmt

/*
 * Generic row for playable items in list views (search, folder contents and
 * the queue). The owning ListView supplies modelData and index; the caller
 * adds optional leading index, trailing text and an action button.
 */
PC3.ItemDelegate {
    id: row

    required property var modelData
    required property int index

    property var client: null

    property int imageSize: 96
    property int artWidth: Kirigami.Units.iconSizes.medium
    property int artHeight: row.artWidth

    property bool showIndex: false
    property string trailingText: ""
    property real trailingOpacity: 0.65

    property string actionIcon: ""
    property string actionTooltip: ""

    // Width of the overlay scrollbar; keeps the action button clickable.
    property real scrollBarWidth: 0

    signal actionTriggered()

    rightPadding: row.scrollBarWidth + Kirigami.Units.smallSpacing

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        PC3.Label {
            Layout.preferredWidth: row.showIndex ? Kirigami.Units.gridUnit * 1.5 : 0
            horizontalAlignment: Text.AlignRight
            visible: row.showIndex
            text: row.index + 1
            opacity: 0.55
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        AlbumArt {
            Layout.preferredWidth: row.artWidth
            Layout.preferredHeight: row.artHeight
            source: row.client ? row.client.imageUrl(row.modelData, row.imageSize) : ""
            fallbackIcon: Fmt.itemIcon(row.modelData)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PC3.Label {
                Layout.fillWidth: true
                text: row.modelData.Name || ""
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PC3.Label {
                Layout.fillWidth: true
                text: Fmt.itemSubtitle(row.modelData)
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: 0.65
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                visible: text.length > 0
            }
        }

        PC3.Label {
            visible: row.trailingText.length > 0
            text: row.trailingText
            opacity: row.trailingOpacity
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        ToolTipButton {
            visible: row.actionIcon.length > 0
            icon.name: row.actionIcon
            tooltip: row.actionTooltip
            onClicked: row.actionTriggered()
        }
    }
}
