/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * KWin helper for Wayland, where Qt's WindowStaysOnTopHint is not mapped to
 * the compositor's "Keep Above" state. The video window title is prefixed with
 * "Emby Video — "; this script keeps all such windows above other windows.
 */
function applyKeepAbove(w) {
    if (!w || !w.caption) {
        return;
    }
    if (w.caption.indexOf("Emby Video — ") === 0 && !w.keepAbove) {
        w.keepAbove = true;
    }
}

workspace.windowList().forEach(applyKeepAbove);
workspace.windowAdded.connect(applyKeepAbove);
