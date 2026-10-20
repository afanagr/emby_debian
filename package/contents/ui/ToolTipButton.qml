/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

/*
 * Tool button with a Plasma tooltip. Keeps the tooltip boilerplate in one
 * place instead of repeating three attached properties for every button.
 */
PC3.ToolButton {
    id: button

    property string tooltip: ""

    PC3.ToolTip.text: button.tooltip
    PC3.ToolTip.visible: button.hovered && button.tooltip.length > 0
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
}
