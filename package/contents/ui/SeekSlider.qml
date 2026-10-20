/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick

import org.kde.plasma.components as PC3

/*
 * Slider bound to PlaybackController position. While the user drags the
 * handle the position updates are ignored, so the slider does not jump back
 * between seeks.
 */
PC3.Slider {
    id: slider

    property var playback: null

    from: 0
    to: Math.max(1, playback ? playback.durationMs : 1)
    enabled: playback !== null && playback.durationMs > 0
    value: 0

    Component.onCompleted: value = playback ? playback.positionMs : 0
    onPlaybackChanged: value = playback ? playback.positionMs : 0
    onMoved: if (playback) playback.seek(value)

    Connections {
        target: slider.playback

        function onPositionMsChanged() {
            if (!slider.pressed) {
                slider.value = slider.playback.positionMs;
            }
        }

        function onTrackChanged() {
            slider.value = 0;
        }
    }
}
