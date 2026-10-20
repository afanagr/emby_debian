/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "Formatting.js" as Fmt

Window {
    id: win

    property var playback: null
    property alias videoOutputItem: videoOut

    readonly property var item: playback ? playback.currentItem : null
    readonly property bool fullScreen: visibility === Window.FullScreen

    width: 960
    height: 540
    minimumWidth: 320
    minimumHeight: 200
    visible: false
    color: "black"
    flags: Qt.Window | Qt.WindowStaysOnTopHint
    title: "Emby Video — " + (item ? (item.Name || "") : "")

    function toggleFullScreen() {
        visibility = fullScreen ? Window.Windowed : Window.FullScreen;
    }

    onClosing: {
        if (playback) {
            playback.requestVideoEmbed();
        }
    }

    Item {
        id: content
        anchors.fill: parent

        VideoOutput {
            id: videoOut
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }

        MouseArea {
            anchors.fill: parent
            onClicked: clickTimer.restart()
            onDoubleClicked: {
                clickTimer.stop();
                win.toggleFullScreen();
            }

            Timer {
                id: clickTimer
                interval: 220
                onTriggered: if (win.playback) win.playback.togglePlayPause()
            }
        }

        Rectangle {
            id: controls
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: controlsLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, 0.92)

            ColumnLayout {
                id: controlsLayout
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PC3.Label {
                        Layout.fillWidth: true
                        text: win.item ? (win.item.Name || "") : "Emby"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.weight: Font.DemiBold
                    }

                    PC3.Label {
                        text: win.item ? Fmt.itemSubtitle(win.item) : ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }

                    ToolTipButton {
                        icon.name: win.playback && win.playback.muted
                                   ? "audio-volume-muted" : "audio-volume-high"
                        onClicked: if (win.playback) win.playback.toggleMute()
                        tooltip: "Выключить звук (M)"
                    }

                    VolumeSlider {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        playback: win.playback
                    }

                    ToolTipButton {
                        icon.name: win.fullScreen ? "view-restore" : "view-fullscreen"
                        onClicked: win.toggleFullScreen()
                        tooltip: "Полный экран (F)"
                    }

                    ToolTipButton {
                        icon.name: "go-down"
                        onClicked: win.close()
                        tooltip: "Вернуть видео в виджет"
                    }

                    ToolTipButton {
                        icon.name: "window-close"
                        onClicked: win.close()
                        tooltip: "Вернуть в виджет и закрыть окно (Esc)"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ToolTipButton {
                        icon.name: "media-skip-backward"
                        onClicked: if (win.playback) win.playback.previous()
                        tooltip: "Предыдущий"
                    }

                    ToolTipButton {
                        icon.name: win.playback && win.playback.playing
                                   ? "media-playback-pause" : "media-playback-start"
                        icon.width: Kirigami.Units.iconSizes.smallMedium
                        icon.height: Kirigami.Units.iconSizes.smallMedium
                        onClicked: if (win.playback) win.playback.togglePlayPause()
                        tooltip: win.playback && win.playback.playing
                                          ? "Пауза (пробел)" : "Воспроизвести (пробел)"
                    }

                    ToolTipButton {
                        icon.name: "media-skip-forward"
                        onClicked: if (win.playback) win.playback.next()
                        tooltip: "Следующий"
                    }

                    PC3.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        horizontalAlignment: Text.AlignRight
                        text: win.playback ? Fmt.formatMs(win.playback.positionMs) : "0:00"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }

                    SeekSlider {
                        Layout.fillWidth: true
                        playback: win.playback
                    }

                    PC3.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        text: win.playback ? Fmt.formatMs(win.playback.durationMs) : "0:00"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }
        }

        Shortcut {
            sequence: "Space"
            onActivated: if (win.playback) win.playback.togglePlayPause()
        }
        Shortcut {
            sequence: "Left"
            onActivated: if (win.playback) win.playback.seek(win.playback.positionMs - 10000)
        }
        Shortcut {
            sequence: "Right"
            onActivated: if (win.playback) win.playback.seek(win.playback.positionMs + 10000)
        }
        Shortcut {
            sequence: "Up"
            onActivated: if (win.playback) win.playback.setVolume(win.playback.volume + 0.05)
        }
        Shortcut {
            sequence: "Down"
            onActivated: if (win.playback) win.playback.setVolume(win.playback.volume - 0.05)
        }
        Shortcut {
            sequence: "M"
            onActivated: if (win.playback) win.playback.toggleMute()
        }
        Shortcut {
            sequence: "F"
            onActivated: win.toggleFullScreen()
        }
        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (win.fullScreen) {
                    win.toggleFullScreen();
                } else {
                    win.close();
                }
            }
        }
    }
}
