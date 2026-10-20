/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

/*
 * On a desktop (Planar form factor) the widget shows the library directly.
 * In a panel it shows the compact now-playing representation; clicking the
 * panel entry opens the full representation in a popup.
 */
Loader {
    id: loader

    property var client: null
    property var playback: null
    property bool videoHostActive: true

    signal logoutRequested()

    readonly property bool planar: Plasmoid.formFactor === PlasmaCore.Types.Planar

    Layout.minimumWidth: planar ? Kirigami.Units.gridUnit * 26
                                : Kirigami.Units.iconSizes.medium
    Layout.minimumHeight: planar ? Kirigami.Units.gridUnit * 26
                                 : Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: planar ? Kirigami.Units.gridUnit * 30
                                  : Kirigami.Units.iconSizes.medium
    Layout.preferredHeight: planar ? Kirigami.Units.gridUnit * 34
                                   : Kirigami.Units.iconSizes.medium

    sourceComponent: planar ? fullComponent : compactComponent

    Component {
        id: fullComponent

        FullRepresentation {
            client: loader.client
            playback: loader.playback
            videoHostActive: loader.videoHostActive
            onLogoutRequested: loader.logoutRequested()
        }
    }

    Component {
        id: compactComponent

        CompactRepresentation {
            client: loader.client
            playback: loader.playback
        }
    }
}
