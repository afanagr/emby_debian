/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * Playback queue and Qt Multimedia backend.
 *
 * This object lives in main.qml (not in the popup representation) so music
 * and video keep playing while the plasmoid popup is closed.
 */

import QtQuick
import QtMultimedia

Item {
    id: root

    property var client: null
    property var videoOutputItem: null
    property bool videoPoppedOut: false
    property bool reportProgress: true

    property var queue: []
    property int currentIndex: -1
    property real volume: 0.7
    property bool muted: false
    property int repeatMode: 0 // 0 = off, 1 = all, 2 = one
    property bool shuffle: false
    property string lastError: ""
    property string playSessionId: ""

    property bool _fallbackTried: false
    property var _reportedItem: null
    property string _reportedSession: ""

    // Number of live embedded video surfaces. Plasma keeps both the visible
    // representation and the preloaded popup one alive, so this is not the
    // same as "an embedded VideoOutput is attached right now".
    property int videoHostCount: 0

    readonly property var currentItem: {
        if (currentIndex < 0 || currentIndex >= queue.length) {
            return null;
        }
        return queue[currentIndex];
    }
    readonly property bool hasVideo: root.isVideo(root.currentItem)
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool paused: player.playbackState === MediaPlayer.PausedState
    readonly property bool stopped: player.playbackState === MediaPlayer.StoppedState
    readonly property int positionMs: player.position
    readonly property int durationMs: {
        if (player.duration > 0) {
            return player.duration;
        }
        if (root.currentItem && root.currentItem.RunTimeTicks) {
            return Math.round(root.currentItem.RunTimeTicks / 10000);
        }
        return 0;
    }

    signal videoStarted()
    signal videoStopped()
    signal trackChanged()
    signal playbackError(string message)
    signal videoPopOutRequested()
    signal videoEmbedRequested()
    signal videoFocusRequested()
    signal showVideoPageRequested()

    function isVideo(item) {
        return root.client ? root.client.isVideo(item) : false;
    }

    function isAudio(item) {
        return root.client ? root.client.isAudio(item) : false;
    }

    function isPlayable(item) {
        return root.client ? root.client.isPlayable(item) : false;
    }

    function registerVideoHost() {
        root.videoHostCount += 1;
    }

    function unregisterVideoHost() {
        root.videoHostCount = Math.max(0, root.videoHostCount - 1);
    }

    function newSessionId() {
        var id = "";
        while (id.length < 32) {
            id += Math.floor(Math.random() * 16).toString(16);
        }
        return id;
    }

    function requestVideoPopOut() {
        if (!root.hasVideo) {
            return;
        }
        root.videoPoppedOut = true;
        root.videoPopOutRequested();
    }

    function requestVideoEmbed() {
        // Let the window hide and detach its VideoOutput first; the visible
        // full representation then attaches its embedded VideoOutput when the
        // videoPoppedOut flag changes below.
        root.videoEmbedRequested();
        root.videoPoppedOut = false;
    }

    function requestShowVideo() {
        if (root.videoPoppedOut) {
            root.videoFocusRequested();
        } else {
            root.showVideoPageRequested();
        }
    }

    function requestVideoFocus() {
        root.videoFocusRequested();
    }

    function setError(message) {
        lastError = message || "Ошибка воспроизведения";
        player.stop();
        videoStopped();
        playbackError(lastError);
    }

    function sendProgress(pausedOverride) {
        if (root.client && root.client.connected && root._reportedItem) {
            var paused = pausedOverride === undefined ? !root.playing : pausedOverride;
            root.client.reportProgress(root._reportedItem, root.positionMs,
                                       root._reportedSession, paused);
        }
    }

    function sendStopped() {
        if (root.client && root.client.connected && root._reportedItem) {
            root.client.reportStopped(root._reportedItem, root.positionMs,
                                      root._reportedSession);
        }
        root._reportedItem = null;
        root._reportedSession = "";
    }

    function startCurrent() {
        var item = root.currentItem;
        if (!item) {
            return;
        }
        if (!root.client || !root.client.connected) {
            setError("Нет подключения к Emby");
            return;
        }

        var session = newSessionId();
        var url = root.client.streamUrl(item, session);
        if (!url || url.length === 0) {
            setError("Не удалось получить ссылку на поток");
            return;
        }

        sendStopped();
        root.playSessionId = session;
        root._fallbackTried = false;
        root.lastError = "";

        player.stop();
        player.source = url;

        root._reportedItem = item;
        root._reportedSession = session;
        root.client.reportStart(item, 0, session, false);

        // Let the active representation attach its VideoOutput before the
        // stream starts, so the first frames are not sent to a stale sink.
        root.trackChanged();
        if (root.hasVideo) {
            root.videoStarted();
        }

        player.play();
    }

    function playItems(items, index) {
        if (!items) {
            return;
        }

        var playable = [];
        for (var i = 0; i < items.length; ++i) {
            if (isPlayable(items[i])) {
                playable.push(items[i]);
            }
        }
        if (playable.length === 0) {
            return;
        }

        var target = 0;
        if (index >= 0 && index < items.length) {
            var wanted = items[index];
            for (var j = 0; j < playable.length; ++j) {
                if (playable[j].Id === wanted.Id) {
                    target = j;
                    break;
                }
            }
        }

        root.queue = playable;
        root.currentIndex = target;
        root.queueChanged();
        startCurrent();
    }

    function playItem(item) {
        playItems([item], 0);
    }

    function play() {
        if (!root.currentItem) {
            return;
        }
        if (!root.client || !root.client.connected) {
            setError("Нет подключения к Emby");
            return;
        }

        if (player.source.toString().length === 0) {
            startCurrent();
            return;
        }
        if (player.mediaStatus === MediaPlayer.EndOfMedia) {
            player.setPosition(0);
        }
        player.play();
        if (root.hasVideo) {
            root.videoStarted();
        }
        if (root.client.connected) {
            root.client.reportStart(root._reportedItem || root.currentItem,
                                    root.positionMs, root._reportedSession, false);
        }
    }

    function pause() {
        if (root.playing) {
            player.pause();
            sendProgress();
        }
    }

    function togglePlayPause() {
        if (root.playing) {
            pause();
        } else {
            play();
        }
    }

    function stop() {
        sendStopped();
        player.stop();
        player.source = "";
        videoStopped();
    }

    function clearQueue() {
        sendStopped();
        root.queue = [];
        root.currentIndex = -1;
        player.stop();
        player.source = "";
        root.queueChanged();
        videoStopped();
    }

    function seek(milliseconds) {
        if (!root.currentItem) {
            return;
        }
        var maximum = root.durationMs > 0 ? root.durationMs : Number(milliseconds);
        var target = Math.max(0, Math.min(maximum, Number(milliseconds) || 0));
        player.setPosition(target);
        sendProgress();
    }

    function advance(auto) {
        if (root.queue.length === 0) {
            return;
        }

        if (auto && root.repeatMode === 2) {
            player.setPosition(0);
            player.play();
            sendProgress();
            return;
        }

        if (root.shuffle && root.queue.length > 1) {
            var nextIndex = root.currentIndex;
            while (nextIndex === root.currentIndex) {
                nextIndex = Math.floor(Math.random() * root.queue.length);
            }
            root.currentIndex = nextIndex;
            startCurrent();
            return;
        }

        if (root.currentIndex + 1 < root.queue.length) {
            root.currentIndex += 1;
            startCurrent();
            return;
        }

        if (root.repeatMode === 1) {
            root.currentIndex = 0;
            startCurrent();
            return;
        }

        if (!auto) {
            player.setPosition(0);
            player.play();
            sendProgress();
        } else {
            // Report the final position so Emby can mark the item as watched.
            sendProgress(false);
        }
    }

    function next() {
        advance(false);
    }

    function previous() {
        if (!root.currentItem) {
            return;
        }
        if (root.positionMs > 3000) {
            seek(0);
            return;
        }
        if (root.currentIndex > 0) {
            root.currentIndex -= 1;
            startCurrent();
            return;
        }
        if (root.repeatMode === 1 && root.queue.length > 0) {
            root.currentIndex = root.queue.length - 1;
            startCurrent();
            return;
        }
        player.setPosition(0);
    }

    function jumpTo(index) {
        if (index < 0 || index >= root.queue.length) {
            return;
        }
        if (index === root.currentIndex) {
            seek(0);
            play();
            return;
        }
        root.currentIndex = index;
        startCurrent();
    }

    function enqueueItems(items) {
        if (!items || items.length === 0) {
            return;
        }

        var added = [];
        for (var i = 0; i < items.length; ++i) {
            if (isPlayable(items[i])) {
                added.push(items[i]);
            }
        }
        if (added.length === 0) {
            return;
        }

        if (root.queue.length === 0) {
            playItems(added, 0);
            return;
        }

        root.queue = root.queue.concat(added);
        root.queueChanged();
    }

    function enqueue(item) {
        enqueueItems([item]);
    }

    function removeFromQueue(index) {
        if (index < 0 || index >= root.queue.length) {
            return;
        }

        if (index === root.currentIndex) {
            var rest = root.queue.slice();
            rest.splice(index, 1);
            if (rest.length === 0) {
                clearQueue();
                return;
            }
            root.queue = rest;
            root.currentIndex = Math.min(index, rest.length - 1);
            root.queueChanged();
            startCurrent();
            return;
        }

        var copy = root.queue.slice();
        copy.splice(index, 1);
        root.queue = copy;
        if (index < root.currentIndex) {
            root.currentIndex -= 1;
        }
        root.queueChanged();
    }

    function setVolume(value) {
        var next = Math.max(0, Math.min(1, Number(value) || 0));
        root.volume = next;
        if (next > 0 && root.muted) {
            root.muted = false;
        }
    }

    function toggleMute() {
        root.muted = !root.muted;
    }

    function cycleRepeat() {
        root.repeatMode = (root.repeatMode + 1) % 3;
    }

    function toggleShuffle() {
        root.shuffle = !root.shuffle;
    }

    function handleError(message) {
        if (!root._fallbackTried && root.currentItem && isAudio(root.currentItem)
                && root.client && root.client.connected) {
            var fallback = root.client.universalAudioUrl(root.currentItem, root.playSessionId);
            if (fallback && fallback.length > 0) {
                root._fallbackTried = true;
                player.stop();
                player.source = fallback;
                player.play();
                return;
            }
        }
        setError(message);
    }

    MediaDevices {
        id: mediaDevices
    }

    MediaPlayer {
        id: player
        videoOutput: root.videoOutputItem
        audioOutput: AudioOutput {
            // Always follow the output selected as default in the system
            // mixer / Plasma audio settings.
            device: mediaDevices.defaultAudioOutput
            volume: root.volume
            muted: root.muted
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                root.advance(true);
            }
        }

        onErrorOccurred: function(error, errorString) {
            if (error !== MediaPlayer.NoError) {
                root.handleError(String(errorString || "Ошибка воспроизведения"));
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.reportProgress && root.playing && root._reportedItem !== null
        onTriggered: root.sendProgress()
    }

    Component.onDestruction: root.sendStopped()
}
