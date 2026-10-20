/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "Formatting.js" as Fmt

Rectangle {
    id: bar

    property var client: null
    property var playback: null

    readonly property var item: playback ? playback.currentItem : null
    readonly property bool hasItem: item !== null && item !== undefined
    readonly property string artwork: client && hasItem ? client.imageUrl(item, 128) : ""

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    color: Kirigami.Theme.backgroundColor

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.12
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            AlbumArt {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: bar.artwork
                fallbackIcon: bar.hasItem ? Fmt.itemIcon(bar.item) : "media-playback-start"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PC3.Label {
                    Layout.fillWidth: true
                    text: bar.hasItem ? (bar.item.Name || "") : "Ничего не воспроизводится"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.weight: Font.DemiBold
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: bar.hasItem ? Fmt.itemSubtitle(bar.item)
                                      : "Выберите музыку или видео в библиотеке"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                PC3.Label {
                    Layout.fillWidth: true
                    visible: playback && playback.lastError.length > 0
                    text: playback ? playback.lastError : ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Kirigami.Theme.negativeTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            ToolTipButton {
                icon.name: "media-skip-backward"
                enabled: bar.hasItem
                onClicked: bar.playback.previous()
                tooltip: "Предыдущий"
            }

            ToolTipButton {
                icon.name: bar.playback && bar.playback.playing
                           ? "media-playback-pause" : "media-playback-start"
                icon.width: Kirigami.Units.iconSizes.smallMedium
                icon.height: Kirigami.Units.iconSizes.smallMedium
                enabled: bar.hasItem
                onClicked: bar.playback.togglePlayPause()
                tooltip: bar.playback && bar.playback.playing
                                  ? "Пауза" : "Воспроизвести"
            }

            ToolTipButton {
                icon.name: "media-skip-forward"
                enabled: bar.hasItem
                onClicked: bar.playback.next()
                tooltip: "Следующий"
            }

            ToolTipButton {
                visible: bar.playback && bar.playback.hasVideo
                icon.name: bar.playback && bar.playback.videoPoppedOut
                           ? "view-restore" : "video-x-generic"
                onClicked: {
                    if (!bar.playback) {
                        return;
                    }
                    if (bar.playback.videoPoppedOut) {
                        bar.playback.requestVideoEmbed();
                    } else {
                        bar.playback.requestShowVideo();
                    }
                }
                tooltip: bar.playback && bar.playback.videoPoppedOut
                                  ? "Вернуть видео в виджет"
                                  : "Показать видео в виджете"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                horizontalAlignment: Text.AlignRight
                text: bar.playback ? Fmt.formatMs(bar.playback.positionMs) : "0:00"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.8
            }

            SeekSlider {
                Layout.fillWidth: true
                playback: bar.playback
            }

            PC3.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                text: bar.playback ? Fmt.formatMs(bar.playback.durationMs) : "0:00"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.8
            }

            ToolTipButton {
                icon.name: "media-playlist-shuffle"
                checkable: true
                checked: bar.playback ? bar.playback.shuffle : false
                enabled: bar.hasItem
                onClicked: bar.playback.toggleShuffle()
                tooltip: "Перемешать"
            }

            ToolTipButton {
                icon.name: bar.playback && bar.playback.repeatMode === 2
                           ? "media-playlist-repeat-song" : "media-playlist-repeat"
                checkable: true
                checked: bar.playback ? bar.playback.repeatMode > 0 : false
                enabled: bar.hasItem
                onClicked: bar.playback.cycleRepeat()
                tooltip: {
                    var mode = bar.playback ? bar.playback.repeatMode : 0;
                    return mode === 2 ? "Повтор трека"
                         : mode === 1 ? "Повтор очереди" : "Повтор выключен";
                }
            }

            ToolTipButton {
                icon.name: bar.playback && bar.playback.muted
                           ? "audio-volume-muted" : "audio-volume-high"
                enabled: bar.hasItem
                onClicked: bar.playback.toggleMute()
                tooltip: "Выключить звук"
            }

            VolumeSlider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                playback: bar.playback
            }
        }
    }
}
