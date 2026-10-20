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
import org.kde.plasma.plasmoid

import "Formatting.js" as Fmt

Item {
    id: full

    property var client: null
    property var playback: null
    // Plasma keeps a preloaded full representation alive for the popup even
    // while it is hidden. Only the representation that is actually shown may
    // attach its VideoOutput to the player, otherwise the hidden copy steals
    // the video sink and the visible widget shows a frozen picture.
    property bool videoHostActive: true

    signal logoutRequested()

    Layout.minimumWidth: Kirigami.Units.gridUnit * 26
    Layout.minimumHeight: Kirigami.Units.gridUnit * 26
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * 34

    // Navigation state.
    property string page: "libraries" // libraries | browse | search | queue | video
    property var history: []
    property var currentParent: null
    property string currentTitle: ""
    property var items: []
    property bool loading: false
    property bool shuffleLoading: false
    property string errorText: ""

    // Search state.
    property var searchResults: []
    property bool searchLoading: false
    property string searchError: ""
    property string searchTerm: ""
    property string pageBeforeSearch: "libraries"

    property string pageBeforeQueue: "libraries"
    property string pageBeforeVideo: "libraries"
    property int navSeq: 0
    property int searchSeq: 0
    property int shuffleSeq: 0
    property bool _pendingVideoPage: false

    readonly property bool connected: client ? client.connected : false
    readonly property bool canGoBack: page === "search" || page === "queue"
                                            || page === "video"
                                            || history.length > 0
    readonly property bool canShuffleCurrent: page === "browse"
                                              && currentParent !== null
    readonly property string headerTitle: {
        if (page === "search") {
            return "Поиск";
        }
        if (page === "queue") {
            return "Очередь";
        }
        if (page === "video") {
            return playback && playback.currentItem
                   ? (playback.currentItem.Name || "Видео") : "Видео";
        }
        if (page === "libraries") {
            if (client && client.serverName) {
                return "Emby · " + client.serverName;
            }
            return "Библиотеки";
        }
        return currentTitle || (currentParent ? currentParent.Name : "Библиотека");
    }
    readonly property string currentCollectionType: {
        var parent = currentParent;
        if (!parent) {
            return "";
        }
        if (parent.CollectionType) {
            return parent.CollectionType;
        }
        if (parent.Type === "MusicAlbum" || parent.Type === "MusicArtist") {
            return "music";
        }
        if (parent.Type === "Series" || parent.Type === "Season") {
            return "tvshows";
        }
        return "";
    }
    readonly property bool listMode: {
        if (page === "search" || page === "queue" || page === "libraries") {
            return true;
        }
        if (items.length === 0) {
            return false;
        }
        for (var i = 0; i < items.length; ++i) {
            var type = items[i].Type;
            if (type === "Audio" || type === "AudioBook" || type === "Episode"
                    || type === "Video" || type === "MusicVideo") {
                return true;
            }
        }
        return false;
    }
    readonly property real cardArtRatio:
        currentCollectionType === "music" ? 1.0 : 1.4

    function gridColumns(width) {
        var step = Kirigami.Units.gridUnit * 7;
        return Math.max(2, Math.floor(width / step));
    }

    function resetNavigation() {
        page = "libraries";
        history = [];
        currentParent = null;
        currentTitle = "";
        items = [];
        loading = false;
        cancelShuffle();
        errorText = "";
        searchResults = [];
        searchLoading = false;
        searchError = "";
        searchTerm = "";
        pageBeforeSearch = "libraries";
        pageBeforeQueue = "libraries";
        pageBeforeVideo = "libraries";
        navSeq += 1;
        searchSeq += 1;
        shuffleSeq += 1;
        if (searchDebounce) {
            searchDebounce.stop();
        }
        if (searchField) {
            searchField.text = "";
        }
    }

    function navigateInto(item) {
        if (!item || !client || !client.canOpen(item)) {
            return;
        }
        cancelShuffle();
        history = history.concat([{
            parent: currentParent,
            title: currentTitle,
            page: page
        }]);
        currentParent = item;
        currentTitle = item.Name || "";
        page = "browse";
        loadChildren(item);
    }

    function loadChildren(parent) {
        if (!client || !parent) {
            return;
        }
        var sequence = ++navSeq;
        loading = true;
        errorText = "";
        items = [];

        client.getChildren(parent, function(error, result) {
            if (sequence !== navSeq) {
                return;
            }
            loading = false;
            if (error) {
                errorText = error;
                return;
            }

            var supported = [];
            for (var i = 0; i < result.length; ++i) {
                if (client.canOpen(result[i])) {
                    supported.push(result[i]);
                }
            }
            items = supported;

            Qt.callLater(function() {
                if (browseLoader.item && browseLoader.item.positionViewAtBeginning) {
                    browseLoader.item.positionViewAtBeginning();
                }
            });
        });
    }

    function videoSurfaceReady() {
        return videoHostActive && visible && width > 0 && height > 0;
    }

    function refreshEmbeddedVideo() {
        if (!playback || !playback.hasVideo || playback.videoPoppedOut) {
            return;
        }
        if (videoSurfaceReady()) {
            if (playback.videoOutputItem !== embeddedVideo.videoOutputItem) {
                playback.videoOutputItem = embeddedVideo.videoOutputItem;
            }
            if (_pendingVideoPage) {
                _pendingVideoPage = false;
                showVideoPage();
            }
        } else if (playback.videoOutputItem === embeddedVideo.videoOutputItem) {
            playback.videoOutputItem = null;
        }
    }

    function showVideoPage() {
        if (!playback || !playback.hasVideo) {
            return;
        }
        if (!videoSurfaceReady()) {
            if (videoHostActive && visible && !playback.videoPoppedOut) {
                _pendingVideoPage = true;
            }
            return;
        }
        _pendingVideoPage = false;
        if (page !== "video") {
            pageBeforeVideo = page;
            page = "video";
        }
        if (!playback.videoPoppedOut) {
            playback.videoOutputItem = embeddedVideo.videoOutputItem;
        }
    }

    function goBack() {
        cancelShuffle();
        if (page === "search") {
            closeSearch();
            return;
        }
        if (page === "queue") {
            closeQueue();
            return;
        }
        if (page === "video") {
            page = pageBeforeVideo || (currentParent ? "browse" : "libraries");
            return;
        }
        if (history.length === 0) {
            return;
        }

        var entry = history[history.length - 1];
        history = history.slice(0, history.length - 1);
        currentParent = entry.parent;
        currentTitle = entry.title;

        if (!entry.parent) {
            page = "libraries";
            items = [];
            loading = false;
            errorText = "";
            navSeq += 1;
        } else {
            page = "browse";
            loadChildren(entry.parent);
        }
    }

    function toggleSearch() {
        cancelShuffle();
        if (page === "search") {
            closeSearch();
            return;
        }
        pageBeforeSearch = page;
        page = "search";
        searchResults = [];
        searchError = "";
        Qt.callLater(function() {
            searchField.forceActiveFocus();
        });
    }

    function closeSearch() {
        searchDebounce.stop();
        searchSeq += 1;
        searchResults = [];
        searchLoading = false;
        searchError = "";
        searchTerm = "";
        searchField.text = "";
        if (pageBeforeSearch === "search") {
            page = currentParent ? "browse" : "libraries";
        } else {
            page = pageBeforeSearch;
        }
    }

    function startSearch(term) {
        var query = String(term || "").trim();
        searchTerm = query;
        var sequence = ++searchSeq;

        if (query.length < 2) {
            searchResults = [];
            searchLoading = false;
            searchError = "";
            return;
        }

        searchLoading = true;
        searchError = "";
        client.search(query, function(error, result) {
            if (sequence !== searchSeq) {
                return;
            }
            searchLoading = false;
            if (error) {
                searchError = error;
                searchResults = [];
                return;
            }

            var supported = [];
            for (var i = 0; i < result.length; ++i) {
                if (client.canOpen(result[i])) {
                    supported.push(result[i]);
                }
            }
            searchResults = supported;
        });
    }

    function cancelShuffle() {
        shuffleSeq += 1;
        shuffleLoading = false;
    }

    function toggleQueue() {
        cancelShuffle();
        if (page === "queue") {
            closeQueue();
            return;
        }
        pageBeforeQueue = page;
        page = "queue";
    }

    function closeQueue() {
        page = pageBeforeQueue === "queue" ? "libraries" : pageBeforeQueue;
    }

    function playFromList(index, item) {
        if (!item || !client || !client.isPlayable(item)) {
            return;
        }
        cancelShuffle();

        var playable = [];
        var target = 0;
        for (var i = 0; i < items.length; ++i) {
            if (client.isPlayable(items[i])) {
                if (items[i].Id === item.Id) {
                    target = playable.length;
                }
                playable.push(items[i]);
            }
        }

        if (playable.length === 0) {
            playback.playItem(item);
        } else {
            playback.playItems(playable, target);
        }
    }

    function activateBrowse(index, item) {
        if (!item) {
            return;
        }
        if (client.isPlayable(item)) {
            playFromList(index, item);
        } else if (client.isBrowsable(item)) {
            navigateInto(item);
        }
    }

    function activateSearch(index, item) {
        if (!item) {
            return;
        }
        if (client.isPlayable(item)) {
            playback.playItem(item);
        } else if (client.isBrowsable(item)) {
            closeSearch();
            navigateInto(item);
        }
    }

    function playAll() {
        if (!playback || items.length === 0) {
            return;
        }
        cancelShuffle();
        var playable = [];
        for (var i = 0; i < items.length; ++i) {
            if (client.isPlayable(items[i])) {
                playable.push(items[i]);
            }
        }
        if (playable.length > 0) {
            playback.playItems(playable, 0);
        }
    }

    function shuffleCurrent() {
        if (!client || !playback || !currentParent || shuffleLoading) {
            return;
        }

        var parentId = currentParent.Id;
        var sequence = ++shuffleSeq;
        shuffleLoading = true;
        errorText = "";

        client.getPlayableDescendants(currentParent, currentCollectionType,
                function(error, result) {
            if (sequence !== shuffleSeq) {
                return;
            }
            if (!currentParent || currentParent.Id !== parentId) {
                shuffleLoading = false;
                return;
            }
            shuffleLoading = false;
            if (error) {
                errorText = error;
                return;
            }

            var found = result || [];
            var playable = [];
            for (var i = 0; i < found.length; ++i) {
                if (client.isPlayable(found[i])) {
                    playable.push(found[i]);
                }
            }
            if (playable.length === 0) {
                errorText = "В этом каталоге нет воспроизводимых элементов";
                return;
            }

            // Emby returns a stable tree; shuffle the complete list locally so
            // every track is queued exactly once in random order.
            for (var j = playable.length - 1; j > 0; --j) {
                var k = Math.floor(Math.random() * (j + 1));
                var swap = playable[j];
                playable[j] = playable[k];
                playable[k] = swap;
            }
            // The queue itself is already shuffled. Disable dynamic shuffle so
            // every element of this catalog is played exactly once.
            playback.shuffle = false;
            playback.playItems(playable, 0);
        });
    }

    function refreshCurrent() {
        if (!client) {
            return;
        }
        if (page === "libraries") {
            client.loadViews();
        } else if (page === "browse" && currentParent) {
            loadChildren(currentParent);
        } else if (page === "search") {
            startSearch(searchField.text);
        }
    }

    function retry() {
        if (page === "browse" && currentParent) {
            loadChildren(currentParent);
        } else if (page === "libraries") {
            client.loadViews();
        }
    }

    function itemIsVideo(item) {
        return client ? client.isVideo(item) : false;
    }

    function playedPercent(item) {
        if (!item || !item.UserData || item.UserData.PlayedPercentage === undefined) {
            return 0;
        }
        return Number(item.UserData.PlayedPercentage) || 0;
    }

    function durationText(item) {
        if (!item) {
            return "";
        }
        if (item.RunTimeTicks) {
            return Fmt.formatTicks(item.RunTimeTicks);
        }
        if (item.ChildCount && (item.Type === "MusicAlbum" || item.Type === "Playlist")) {
            return Fmt.trackCountText(item.ChildCount);
        }
        return "";
    }

    function typeLabel(item) {
        if (!item) {
            return "";
        }
        switch (item.Type) {
        case "Audio": return "Трек";
        case "AudioBook": return "Аудиокнига";
        case "MusicAlbum": return "Альбом";
        case "MusicArtist": return "Исполнитель";
        case "Movie": return "Фильм";
        case "Episode": return "Серия";
        case "Series": return "Сериал";
        case "Season": return "Сезон";
        case "Video": return "Видео";
        case "MusicVideo": return "Клип";
        case "Playlist": return "Плейлист";
        case "BoxSet": return "Коллекция";
        case "Folder": return "Папка";
        default: return "";
        }
    }

    Loader {
        anchors.fill: parent
        active: !full.connected
        sourceComponent: loginComponent
    }

    ColumnLayout {
        anchors.fill: parent
        visible: full.connected
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            ToolTipButton {
                visible: full.canGoBack
                icon.name: "go-previous"
                onClicked: full.goBack()
                tooltip: "Назад"
            }

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: full.headerTitle
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PC3.BusyIndicator {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                running: full.loading || full.searchLoading || full.shuffleLoading
                visible: running
            }

            ToolTipButton {
                visible: full.canShuffleCurrent
                enabled: !full.shuffleLoading
                icon.name: "media-playlist-shuffle"
                onClicked: full.shuffleCurrent()
                tooltip: "Перемешать весь каталог"
            }

            ToolTipButton {
                icon.name: "search"
                checkable: true
                checked: full.page === "search"
                onClicked: full.toggleSearch()
                tooltip: "Поиск (Ctrl+F)"
            }

            ToolTipButton {
                icon.name: "view-media-playlist"
                onClicked: full.toggleQueue()
                tooltip: "Очередь воспроизведения"
            }

            ToolTipButton {
                id: menuButton
                icon.name: "application-menu"
                onClicked: menu.open()
                tooltip: "Меню"

                PC3.Menu {
                    id: menu
                    y: menuButton.height
                    x: menuButton.width - width

                    PC3.MenuItem {
                        icon.name: "view-refresh"
                        text: "Обновить"
                        onTriggered: full.refreshCurrent()
                    }
                    PC3.MenuItem {
                        icon.name: "media-playback-start"
                        text: "Воспроизвести всё"
                        enabled: full.items.length > 0 && full.page === "browse"
                        onTriggered: full.playAll()
                    }
                    PC3.MenuItem {
                        icon.name: "media-playlist-shuffle"
                        text: "Перемешать весь каталог"
                        enabled: full.canShuffleCurrent && !full.shuffleLoading
                        onTriggered: full.shuffleCurrent()
                    }
                    PC3.MenuSeparator {}
                    PC3.MenuItem {
                        icon.name: "configure"
                        text: "Настройки Emby"
                        onTriggered: {
                            var configureAction = Plasmoid.internalAction("configure");
                            if (configureAction) {
                                configureAction.trigger();
                            }
                        }
                    }
                    PC3.MenuSeparator {}
                    PC3.MenuItem {
                        icon.name: "system-log-out"
                        text: "Выйти из аккаунта"
                        onTriggered: full.logoutRequested()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: full.page === "search"
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true

                onAccepted: {
                    searchDebounce.stop();
                    full.startSearch(text);
                }

                onTextChanged: {
                    if (text.trim().length < 2) {
                        full.searchSeq += 1;
                        full.searchResults = [];
                        full.searchLoading = false;
                        full.searchError = "";
                        searchDebounce.stop();
                    } else {
                        searchDebounce.restart();
                    }
                }
            }

            ToolTipButton {
                icon.name: "dialog-close"
                onClicked: full.closeSearch()
                tooltip: "Закрыть поиск"
            }
        }

        Timer {
            id: searchDebounce
            interval: 450
            onTriggered: full.startSearch(searchField.text)
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: full.page === "libraries" ? 0
                        : full.page === "browse" ? 1
                        : full.page === "search" ? 2
                        : full.page === "queue" ? 3 : 4

            Item {
                ListView {
                    id: librariesList
                    anchors.fill: parent
                    clip: true
                    model: full.client ? full.client.views : []

                    delegate: PC3.ItemDelegate {
                        required property var modelData

                        width: ListView.view.width
                        rightPadding: librariesScrollBar.implicitWidth
                                      + Kirigami.Units.smallSpacing
                        icon.name: Fmt.libraryIcon(modelData)
                        text: modelData.Name || ""
                        onClicked: full.navigateInto(modelData)
                    }

                    PC3.ScrollBar.vertical: PC3.ScrollBar {
                        id: librariesScrollBar
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: librariesList.count === 0 && !full.loading
                    iconName: full.client && full.client.viewsError
                              ? "dialog-error" : "folder"
                    text: full.client && full.client.viewsError
                          ? "Не удалось загрузить библиотеку"
                          : "Библиотеки не найдены"
                    explanation: full.client && full.client.viewsError
                                 ? full.client.viewsError
                                 : "Проверьте права пользователя на сервере Emby."
                    helpfulAction: Kirigami.Action {
                        text: "Обновить"
                        icon.name: "view-refresh"
                        onTriggered: if (full.client) full.client.loadViews()
                    }
                }
            }

            Item {
                Loader {
                    id: browseLoader
                    anchors.fill: parent
                    active: full.page === "browse"
                    sourceComponent: full.listMode ? browseListComponent : browseGridComponent
                }

                PC3.BusyIndicator {
                    anchors.centerIn: parent
                    running: full.loading
                    visible: running
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 4,
                                    Kirigami.Units.gridUnit * 24)
                    visible: full.page === "browse" && !full.loading
                             && full.errorText.length > 0
                    iconName: "dialog-error"
                    text: "Не удалось загрузить содержимое"
                    explanation: full.errorText
                    helpfulAction: Kirigami.Action {
                        text: "Повторить"
                        icon.name: "view-refresh"
                        onTriggered: full.retry()
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 4,
                                    Kirigami.Units.gridUnit * 24)
                    visible: full.page === "browse" && !full.loading
                             && full.errorText.length === 0 && full.items.length === 0
                    iconName: "folder-open"
                    text: "Здесь пока ничего нет"
                    explanation: "В этой папке нет элементов, которые умеет открывать виджет."
                }
            }

            Item {
                ListView {
                    id: searchList
                    anchors.fill: parent
                    clip: true
                    model: full.searchResults

                    delegate: MediaRow {
                        width: ListView.view.width
                        scrollBarWidth: searchScrollBar.implicitWidth
                        client: full.client
                        imageSize: 96
                        trailingText: full.typeLabel(modelData)
                        trailingOpacity: 0.55
                        onClicked: full.activateSearch(index, modelData)
                    }

                    PC3.ScrollBar.vertical: PC3.ScrollBar {
                        id: searchScrollBar
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: !full.searchLoading && full.searchResults.length === 0
                    iconName: full.searchError ? "dialog-error" : "search"
                    text: full.searchError ? "Ошибка поиска"
                          : (full.searchTerm.length >= 2
                             ? "Ничего не найдено" : "Введите минимум 2 символа")
                    explanation: full.searchError ? full.searchError
                                 : "Поиск выполняется по всей библиотеке Emby."
                }
            }

            QueueView {
                client: full.client
                playback: full.playback
            }

            EmbeddedVideo {
                id: embeddedVideo
                playback: full.playback
            }
        }

        PlayerBar {
            Layout.fillWidth: true
            client: full.client
            playback: full.playback
        }
    }

    Component {
        id: loginComponent
        LoginView {
            client: full.client
        }
    }

    Component {
        id: browseGridComponent

        GridView {
            id: browseGrid
            clip: true
            model: full.items
            readonly property int columns: full.gridColumns(width)
            cellWidth: Math.max(1, Math.floor(width / columns))
            cellHeight: Math.round(cellWidth * full.cardArtRatio
                                   + Kirigami.Units.gridUnit * 3.2)

            delegate: PC3.ItemDelegate {
                id: card

                required property var modelData
                required property int index

                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                padding: Kirigami.Units.smallSpacing
                onClicked: full.activateBrowse(index, modelData)

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * full.cardArtRatio)

                        AlbumArt {
                            anchors.fill: parent
                            source: full.client
                                    ? full.client.imageUrl(modelData, full.client.imageSize) : ""
                            fallbackIcon: Fmt.itemIcon(modelData)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 3
                            color: Qt.rgba(0, 0, 0, 0.35)
                            visible: full.playedPercent(modelData) > 0
                                     && full.playedPercent(modelData) < 100

                            Rectangle {
                                width: parent.width * full.playedPercent(modelData) / 100
                                height: parent.height
                                color: Kirigami.Theme.highlightColor
                            }
                        }
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        text: modelData.Name || ""
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        font.weight: Font.DemiBold
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        text: Fmt.itemSubtitle(modelData)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: 0.65
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        visible: text.length > 0
                    }
                }
            }

            PC3.ScrollBar.vertical: PC3.ScrollBar {}
        }
    }

    Component {
        id: browseListComponent

        ListView {
            id: browseList
            clip: true
            model: full.items

            delegate: MediaRow {
                id: listRow

                readonly property bool videoRow: full.itemIsVideo(modelData)

                width: ListView.view.width
                scrollBarWidth: browseScrollBar.implicitWidth
                client: full.client
                imageSize: 160
                artWidth: listRow.videoRow ? Kirigami.Units.gridUnit * 4
                                           : Kirigami.Units.gridUnit * 2.4
                artHeight: listRow.videoRow ? Kirigami.Units.gridUnit * 2.25
                                            : Kirigami.Units.gridUnit * 2.4
                trailingText: full.durationText(modelData)
                actionIcon: "media-playlist-append"
                actionTooltip: "Добавить в очередь"
                highlighted: full.playback && full.playback.currentItem
                             && full.playback.currentItem.Id === modelData.Id
                onClicked: full.activateBrowse(index, modelData)
                onActionTriggered: full.playback.enqueue(modelData)
            }

            PC3.ScrollBar.vertical: PC3.ScrollBar {
                id: browseScrollBar
            }
        }
    }

    Connections {
        target: full.client

        function onLoginSucceeded() {
            full.resetNavigation();
        }

        function onSessionEnded() {
            full.resetNavigation();
        }
    }

    Connections {
        target: full.playback

        function onVideoStarted() {
            if (!full.playback.videoPoppedOut) {
                full.showVideoPage();
            }
        }

        function onTrackChanged() {
            if (full.playback.hasVideo) {
                if (!full.playback.videoPoppedOut) {
                    full.showVideoPage();
                }
            } else if (full.page === "video") {
                full.page = full.pageBeforeVideo
                            || (full.currentParent ? "browse" : "libraries");
            }
        }

        function onVideoStopped() {
            if (full.page === "video") {
                full.page = full.pageBeforeVideo
                            || (full.currentParent ? "browse" : "libraries");
            }
        }

        function onVideoPoppedOutChanged() {
            if (full.playback.videoPoppedOut) {
                if (full.playback.videoOutputItem === embeddedVideo.videoOutputItem) {
                    full.playback.videoOutputItem = null;
                }
            } else if (full.playback.hasVideo) {
                full.showVideoPage();
            }
        }

        function onShowVideoPageRequested() {
            full.showVideoPage();
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            if (full.page !== "search") {
                full.toggleSearch();
            } else {
                searchField.forceActiveFocus();
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Right"
        enabled: !searchField.activeFocus
        onActivated: if (full.playback) full.playback.next()
    }

    Shortcut {
        sequence: "Ctrl+Left"
        enabled: !searchField.activeFocus
        onActivated: if (full.playback) full.playback.previous()
    }

    Shortcut {
        sequence: "Ctrl+M"
        enabled: !searchField.activeFocus
        onActivated: if (full.playback) full.playback.toggleMute()
    }

    Component.onCompleted: {
        if (full.connected) {
            full.resetNavigation();
        }

        if (full.playback) {
            full.playback.registerVideoHost();
            full.refreshEmbeddedVideo();
            if (full.playback.hasVideo && !full.playback.videoPoppedOut) {
                full.showVideoPage();
            }
        }
    }

    onWidthChanged: refreshEmbeddedVideo()
    onHeightChanged: refreshEmbeddedVideo()
    onVisibleChanged: {
        refreshEmbeddedVideo();
        if (visible && videoHostActive && playback && playback.hasVideo
                && !playback.videoPoppedOut) {
            showVideoPage();
        }
    }
    onVideoHostActiveChanged: {
        refreshEmbeddedVideo();
        if (videoHostActive && playback && playback.hasVideo
                && !playback.videoPoppedOut) {
            showVideoPage();
        }
    }

    Component.onDestruction: {
        if (full.playback
                && full.playback.videoOutputItem === embeddedVideo.videoOutputItem) {
            full.playback.videoOutputItem = null;
        }
        if (full.playback) {
            full.playback.unregisterVideoHost();
        }
    }
}
