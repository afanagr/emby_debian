/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "Formatting.js" as Fmt

Item {
    id: queueView

    property var client: null
    property var playback: null

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: "Очередь"
                font.weight: Font.DemiBold
            }

            PC3.Label {
                text: playback && playback.queue.length > 0
                      ? "· " + playback.queue.length : ""
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            Item {
                Layout.fillWidth: true
            }

            PC3.Button {
                icon.name: "edit-clear-all"
                text: "Очистить"
                enabled: playback && playback.queue.length > 0
                onClicked: playback.clearQueue()
                PC3.ToolTip.text: "Очистить очередь и остановить воспроизведение"
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: queueList
                anchors.fill: parent
                clip: true
                spacing: 0
                model: playback ? playback.queue : []

                delegate: MediaRow {
                    width: ListView.view.width
                    scrollBarWidth: queueScrollBar.implicitWidth
                    client: queueView.client
                    imageSize: 96
                    artWidth: Kirigami.Units.iconSizes.smallMedium
                    artHeight: Kirigami.Units.iconSizes.smallMedium
                    showIndex: true
                    trailingText: Fmt.formatTicks(modelData.RunTimeTicks)
                    actionIcon: "list-remove"
                    actionTooltip: "Убрать из очереди"
                    highlighted: queueView.playback.currentIndex === index
                    onClicked: queueView.playback.jumpTo(index)
                    onActionTriggered: queueView.playback.removeFromQueue(index)
                }

                PC3.ScrollBar.vertical: PC3.ScrollBar {
                    id: queueScrollBar
                }
            }

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: queueList.count === 0
                iconName: "view-media-playlist"
                text: "Очередь пуста"
                explanation: "Запустите альбом или добавьте треки кнопкой «В очередь»."
            }
        }
    }
}
