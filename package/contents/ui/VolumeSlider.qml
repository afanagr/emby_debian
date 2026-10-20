/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick

import org.kde.plasma.components as PC3

/*
 * Slider bound to PlaybackController volume.
 */
PC3.Slider {
    id: slider

    property var playback: null

    from: 0
    to: 1
    value: playback ? playback.volume : 0

    onMoved: if (playback) playback.setVolume(value)

    Connections {
        target: slider.playback

        function onVolumeChanged() {
            if (!slider.pressed) {
                slider.value = slider.playback.volume;
            }
        }
    }
}
