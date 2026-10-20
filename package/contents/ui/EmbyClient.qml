/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * Small Emby REST client for the plasmoid.
 *
 * The widget talks to Emby directly with XMLHttpRequest, so no daemon or
 * extra Python packages are needed. Playback is handled by Qt Multimedia in
 * PlaybackController.qml.
 */

import QtQuick

Item {
    id: root

    // Settings (assigned by main.qml from the plasmoid configuration).
    property string serverUrl: ""
    property string apiKey: ""
    property string username: ""
    property string password: ""
    property string deviceName: "Plasma Desktop"
    property string deviceId: ""
    property int itemLimit: 300
    property int imageSize: 300

    // Session.
    property string token: ""
    property string userId: ""
    property string userName: ""
    property string serverName: ""
    property string serverVersion: ""
    property string serverId: ""
    property bool connected: false
    property bool connecting: false
    property string status: "idle" // idle | connecting | connected | error | unconfigured
    property string lastError: ""
    property var views: []
    property string viewsError: ""

    readonly property string clientName: "Emby Plasma"
    // Keep in sync with package/metadata.json.
    readonly property string clientVersion: "1.0.0"
    // Upper bound for recursive "shuffle the whole catalog" queries.
    readonly property int maxItemLimit: 5000

    readonly property string itemFields: "PrimaryImageAspectRatio,Overview,ProductionYear,ChildCount,"
        + "Album,AlbumId,AlbumArtist,AlbumArtists,Artists,ArtistItems,AlbumPrimaryImageTag,"
        + "SeriesId,SeriesName,SeriesPrimaryImageTag,SeasonId,SeasonName,IndexNumber,ParentIndexNumber,"
        + "RunTimeTicks,UserData,MediaSources,MediaStreams,Genres,OfficialRating,"
        + "ImageTags,PrimaryImageTag,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags"

    signal loginSucceeded()
    signal connectionFailed(string message)
    signal sessionEnded()

    // Keep in-flight XMLHttpRequest objects alive until they finish.
    property var _requests: []

    // ---------------------------------------------------------------------
    // URLs and HTTP
    // ---------------------------------------------------------------------

    function normalizeServerUrl(value) {
        var url = String(value || "").trim();
        if (url.length === 0) {
            return "";
        }
        if (!/^https?:\/\//i.test(url)) {
            url = "http://" + url;
        }
        return url.replace(/\/+$/, "");
    }

    // Emby normally exposes its API below /emby. The address stored in the
    // configuration is the address the user typed; a custom reverse-proxy
    // prefix is respected as-is.
    function apiRoot() {
        var base = normalizeServerUrl(serverUrl);
        if (base.length === 0) {
            return "";
        }
        var root = base.replace(/\/web$/i, "");
        if (/\/emby$/i.test(root) || /\/mediabrowser$/i.test(root)) {
            return root;
        }
        var path = root.replace(/^https?:\/\/[^\/]+/i, "");
        if (path.length > 0) {
            return root;
        }
        return root + "/emby";
    }

    function queryString(params) {
        var parts = [];
        for (var key in params) {
            if (!Object.prototype.hasOwnProperty.call(params, key)) {
                continue;
            }
            var value = params[key];
            if (value === undefined || value === null || value === "") {
                continue;
            }
            parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(value)));
        }
        return parts.join("&");
    }

    function buildUrl(path, params, withToken) {
        var url = apiRoot() + path;
        var all = {};
        if (params) {
            for (var key in params) {
                if (Object.prototype.hasOwnProperty.call(params, key)) {
                    all[key] = params[key];
                }
            }
        }
        if (withToken && token.length > 0) {
            all["api_key"] = token;
        }
        var query = queryString(all);
        return query.length > 0 ? url + "?" + query : url;
    }

    function effectiveDeviceId() {
        if (deviceId.length === 0) {
            deviceId = "emby-plasma-" + Math.random().toString(36).substring(2, 10)
                + Date.now().toString(36);
        }
        return deviceId;
    }

    function authorizationHeader() {
        var device = String(deviceName || "Plasma Desktop").replace(/"/g, "'");
        return 'MediaBrowser Client="' + clientName + '", Device="' + device
            + '", DeviceId="' + effectiveDeviceId() + '", Version="' + clientVersion + '"';
    }

    function rememberRequest(xhr) {
        var next = _requests.slice();
        next.push(xhr);
        _requests = next;
    }

    function forgetRequest(xhr) {
        var next = [];
        for (var i = 0; i < _requests.length; ++i) {
            if (_requests[i] !== xhr) {
                next.push(_requests[i]);
            }
        }
        _requests = next;
    }

    /*
     * callback(message, data, httpStatus)
     *   message is null on success and a human readable error otherwise.
     */
    function request(method, path, params, body, callback, withToken) {
        var xhr = new XMLHttpRequest();
        var finished = false;

        function finish(message, data, httpStatus) {
            if (finished) {
                return;
            }
            finished = true;
            if (root && typeof root.forgetRequest === "function") {
                root.forgetRequest(xhr);
            }
            if (root && callback) {
                callback(message, data, httpStatus);
            }
        }

        if (apiRoot().length === 0) {
            finish("Укажите адрес сервера Emby", null, 0);
            return;
        }

        var url = buildUrl(path, params, withToken);
        rememberRequest(xhr);

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            var data = null;
            if (xhr.responseText && xhr.responseText.length > 0) {
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (error) {
                    data = xhr.responseText;
                }
            }

            if (xhr.status >= 200 && xhr.status < 300) {
                finish(null, data, xhr.status);
                return;
            }

            var message = "";
            if (data && typeof data === "object") {
                message = data.error || data.message || "";
            }
            if (message.length === 0) {
                if (xhr.status === 0) {
                    message = "Не удалось подключиться к серверу Emby. Проверьте адрес и сеть.";
                } else if (xhr.status === 401 || xhr.status === 403) {
                    message = "Сервер отклонил логин или токен";
                } else if (xhr.status === 404) {
                    message = "Запрашиваемый ресурс не найден на сервере";
                } else {
                    message = "Сервер Emby вернул ошибку HTTP " + xhr.status;
                }
            } else {
                message = "Сервер Emby: " + message;
            }
            finish(message, data, xhr.status);
        };

        xhr.ontimeout = function() {
            finish("Превышено время ожидания ответа сервера Emby", null, 0);
        };
        xhr.onerror = function() {
            finish("Не удалось подключиться к серверу Emby. Проверьте адрес и сеть.", null, 0);
        };

        try {
            xhr.open(method, url);
            xhr.timeout = 25000;
            xhr.setRequestHeader("Accept", "application/json");
            xhr.setRequestHeader("X-Emby-Authorization", authorizationHeader());
            if (withToken && token.length > 0) {
                xhr.setRequestHeader("X-Emby-Token", token);
            }
            if (body !== undefined && body !== null) {
                xhr.setRequestHeader("Content-Type", "application/json");
            }
            xhr.send(body !== undefined && body !== null ? JSON.stringify(body) : null);
        } catch (error) {
            finish("Не удалось выполнить запрос к Emby: " + error, null, 0);
        }
    }

    // ---------------------------------------------------------------------
    // Authentication
    // ---------------------------------------------------------------------

    function connect() {
        if (connecting) {
            return;
        }

        var normalized = normalizeServerUrl(serverUrl);
        if (normalized.length === 0) {
            fail("Укажите адрес сервера Emby", "unconfigured");
            return;
        }

        serverUrl = normalized;
        connecting = true;
        connected = false;
        status = "connecting";
        lastError = "";
        viewsError = "";
        effectiveDeviceId();

        if (apiKey.length > 0) {
            token = apiKey;
            validateSession(true);
        } else if (token.length > 0) {
            validateSession(false);
        } else if (username.length > 0 && password.length > 0) {
            authenticate();
        } else {
            fail("Введите API-ключ или имя пользователя и пароль", "unconfigured");
        }
    }

    function fail(message, newStatus) {
        connected = false;
        connecting = false;
        status = newStatus || "error";
        lastError = message;
        connectionFailed(message);
    }

    function validateSession(usingApiKey) {
        resolveUser(function(error, user, httpStatus) {
            if (error) {
                if (httpStatus === 401 || httpStatus === 403) {
                    if (username.length > 0 && password.length > 0) {
                        token = "";
                        authenticate();
                    } else if (usingApiKey) {
                        fail("Сервер отклонил API-ключ", "error");
                    } else {
                        fail("Сессия недействительна. Войдите в Emby снова.", "error");
                    }
                    return;
                }
                fail(error, "error");
                return;
            }
            completeLogin(user);
        });
    }

    function resolveUser(callback) {
        if (userId.length > 0) {
            request("GET", "/Users/" + encodeURIComponent(userId), null, null,
                    function(error, user, httpStatus) {
                if (!error && user && user.Id) {
                    callback(null, user, httpStatus);
                    return;
                }
                if (httpStatus === 0) {
                    callback(error, null, httpStatus);
                    return;
                }
                resolveUserFromList(callback);
            }, true);
        } else {
            resolveUserFromList(callback);
        }
    }

    function resolveUserFromList(callback) {
        request("GET", "/Users/Me", null, null, function(error, user, httpStatus) {
            if (!error && user && user.Id) {
                callback(null, user, httpStatus);
                return;
            }
            if (httpStatus === 0) {
                callback(error, null, httpStatus);
                return;
            }

            request("GET", "/Users", null, null, function(listError, data, listStatus) {
                if (listError) {
                    callback(listError, null, listStatus);
                    return;
                }

                var list = [];
                if (data && data.Items) {
                    list = data.Items;
                } else if (data && data.length !== undefined) {
                    list = data;
                }
                if (list.length === 0) {
                    callback("На сервере не найдено ни одного пользователя", null, 404);
                    return;
                }

                var chosen = null;
                for (var i = 0; i < list.length; ++i) {
                    if (username.length > 0 && list[i].Name === username) {
                        chosen = list[i];
                        break;
                    }
                }
                if (!chosen) {
                    for (var j = 0; j < list.length; ++j) {
                        if (list[j].Policy && list[j].Policy.IsDisabled) {
                            continue;
                        }
                        chosen = list[j];
                        break;
                    }
                }
                if (!chosen) {
                    chosen = list[0];
                }
                callback(null, chosen, listStatus);
            }, true);
        }, true);
    }

    function authenticate() {
        request("POST", "/Users/AuthenticateByName", null,
                { Username: username, Pw: password },
                function(error, data, httpStatus) {
            if (error) {
                if (httpStatus === 401 || httpStatus === 403) {
                    fail("Неверное имя пользователя или пароль", "error");
                } else {
                    fail(error, "error");
                }
                return;
            }

            var accessToken = data ? data.AccessToken : "";
            var user = data ? data.User : null;
            if (!accessToken || !user || !user.Id) {
                fail("Сервер не вернул токен доступа", "error");
                return;
            }

            token = String(accessToken);
            userId = String(user.Id);
            userName = user.Name || username;
            serverId = data.ServerId || serverId;
            completeLogin(user);
        }, false);
    }

    function completeLogin(user) {
        if (user && user.Id) {
            userId = String(user.Id);
        }
        if (user && user.Name) {
            userName = user.Name;
        }
        connected = true;
        connecting = false;
        status = "connected";
        lastError = "";
        fetchServerInfo();
        loginSucceeded();
        loadViews();
    }

    function fetchServerInfo() {
        request("GET", "/System/Info/Public", null, null, function(error, data) {
            if (error || !data) {
                return;
            }
            if (data.ServerName) {
                serverName = data.ServerName;
            }
            if (data.Version) {
                serverVersion = data.Version;
            }
            if (data.Id) {
                serverId = data.Id;
            }
        }, false);
    }

    function logout() {
        if (token.length > 0) {
            request("POST", "/Sessions/Logout", null, null, function() {}, true);
        }
        token = "";
        userId = "";
        userName = "";
        connected = false;
        connecting = false;
        status = "idle";
        lastError = "";
        views = [];
        viewsError = "";
        sessionEnded();
    }

    // ---------------------------------------------------------------------
    // Library browsing
    // ---------------------------------------------------------------------

    function loadViews(callback) {
        if (!connected || userId.length === 0) {
            if (callback) {
                callback("Нет подключения к Emby");
            }
            return;
        }

        viewsError = "";
        request("GET", "/Users/" + encodeURIComponent(userId) + "/Views", null, null,
                function(error, data) {
            if (error) {
                viewsError = error;
                if (callback) {
                    callback(error);
                }
                return;
            }
            views = (data && data.Items) ? data.Items : [];
            if (callback) {
                callback(null);
            }
        }, true);
    }

    function getItems(params, callback) {
        if (!connected || userId.length === 0) {
            callback("Нет подключения к Emby", []);
            return;
        }

        var query = {};
        for (var key in params) {
            if (Object.prototype.hasOwnProperty.call(params, key)) {
                query[key] = params[key];
            }
        }
        query.UserId = query.UserId || userId;
        query.Fields = query.Fields || itemFields;
        query.ImageTypeLimit = 1;
        query.EnableImageTypes = "Primary";
        query.Limit = query.Limit || itemLimit;

        request("GET", "/Users/" + encodeURIComponent(userId) + "/Items", query, null,
                function(error, data) {
            callback(error, error ? [] : ((data && data.Items) ? data.Items : []));
        }, true);
    }

    function getChildren(parent, callback) {
        if (!parent) {
            callback(null, views.slice());
            return;
        }

        var type = parent.Type || "";

        if (type === "Series") {
            request("GET", "/Shows/" + encodeURIComponent(parent.Id) + "/Seasons",
                    { UserId: userId, Fields: itemFields, Limit: itemLimit }, null,
                    function(error, data) {
                callback(error, error ? [] : ((data && data.Items) ? data.Items : []));
            }, true);
            return;
        }

        if (type === "Season") {
            var seriesId = parent.SeriesId || parent.Id;
            var episodeParams = {
                UserId: userId,
                Fields: itemFields,
                SortBy: "ParentIndexNumber,IndexNumber,SortName",
                Limit: itemLimit
            };
            if (parent.SeriesId) {
                episodeParams.SeasonId = parent.Id;
            }
            request("GET", "/Shows/" + encodeURIComponent(seriesId) + "/Episodes",
                    episodeParams, null,
                    function(error, data) {
                callback(error, error ? [] : ((data && data.Items) ? data.Items : []));
            }, true);
            return;
        }

        if (type === "Playlist") {
            request("GET", "/Playlists/" + encodeURIComponent(parent.Id) + "/Items",
                    { UserId: userId, Fields: itemFields, Limit: Math.max(itemLimit, 500) }, null,
                    function(error, data) {
                callback(error, error ? [] : ((data && data.Items) ? data.Items : []));
            }, true);
            return;
        }

        if (type === "MusicAlbum") {
            getItems({
                ParentId: parent.Id,
                IncludeItemTypes: "Audio",
                Recursive: true,
                SortBy: "ParentIndexNumber,IndexNumber,SortName",
                Limit: 500
            }, callback);
            return;
        }

        if (type === "MusicArtist") {
            getItems({
                ArtistIds: parent.Id,
                IncludeItemTypes: "MusicAlbum",
                Recursive: true,
                SortBy: "ProductionYear,SortName",
                Limit: itemLimit
            }, callback);
            return;
        }

        if (type === "BoxSet") {
            getItems({
                ParentId: parent.Id,
                Recursive: false,
                SortBy: "SortName",
                Limit: itemLimit
            }, callback);
            return;
        }

        /*
         * Libraries and folders are imported exactly as Emby returns them.
         * Do not filter the direct children by item type here: a music library
         * may contain artist folders instead of MusicAlbum items, and a
         * "music videos" library may contain folders with MusicVideo items
         * inside. Filtering only by MusicAlbum/MusicVideo made such libraries
         * appear empty. The UI only hides types it cannot open.
         */
        getItems({
            ParentId: parent.Id,
            Recursive: false,
            SortBy: "SortName",
            Limit: itemLimit
        }, callback);
    }

    /*
     * All playable descendants of a library/folder/artist/album. Used by the
     * "shuffle catalog" action; unlike getChildren(), this walks the whole
     * tree so a music library is not limited to its top-level folders.
     */
    function getPlayableDescendants(parent, collectionType, callback) {
        if (!connected || userId.length === 0) {
            callback("Нет подключения к Emby", []);
            return;
        }
        if (!parent) {
            callback(null, []);
            return;
        }

        var type = parent.Type || "";
        var include = "";
        if (collectionType === "music" || type === "MusicAlbum"
                || type === "MusicArtist") {
            include = "Audio,AudioBook";
        } else if (collectionType === "musicvideos") {
            include = "MusicVideo,Video";
        } else if (collectionType === "movies") {
            include = "Movie,Episode,Video,MusicVideo";
        } else if (collectionType === "tvshows") {
            include = "Episode,Video";
        } else {
            include = "Audio,AudioBook,MusicVideo,Video,Movie,Episode";
        }

        function handle(error, data) {
            callback(error, error ? [] : ((data && data.Items) ? data.Items : []));
        }

        if (type === "Series" || type === "Season") {
            var seriesId = parent.SeriesId || parent.Id;
            var episodeParams = {
                UserId: userId,
                Fields: itemFields,
                SortBy: "SortName",
                Limit: maxItemLimit
            };
            if (type === "Season") {
                episodeParams.SeasonId = parent.Id;
            }
            request("GET", "/Shows/" + encodeURIComponent(seriesId) + "/Episodes",
                    episodeParams, null, handle, true);
            return;
        }

        if (type === "Playlist") {
            request("GET", "/Playlists/" + encodeURIComponent(parent.Id) + "/Items",
                    { UserId: userId, Fields: itemFields, Limit: maxItemLimit }, null,
                    handle, true);
            return;
        }

        if (type === "MusicArtist") {
            getItems({
                ArtistIds: parent.Id,
                IncludeItemTypes: include,
                Recursive: true,
                SortBy: "SortName",
                Limit: maxItemLimit
            }, callback);
            return;
        }

        getItems({
            ParentId: parent.Id,
            Recursive: true,
            IncludeItemTypes: include,
            SortBy: "SortName",
            Limit: maxItemLimit
        }, callback);
    }

    function search(term, callback) {
        var query = String(term || "").trim();
        if (query.length < 2) {
            callback(null, []);
            return;
        }
        getItems({
            SearchTerm: query,
            Recursive: true,
            IncludeItemTypes: "Movie,Series,Episode,MusicAlbum,MusicArtist,Audio,Video,MusicVideo,Playlist,BoxSet",
            SortBy: "SortName",
            Limit: 100
        }, callback);
    }

    // ---------------------------------------------------------------------
    // Media URLs
    // ---------------------------------------------------------------------

    function imageUrl(item, size) {
        if (!item || token.length === 0 || apiRoot().length === 0) {
            return "";
        }

        var imageId = "";
        var tag = "";
        var tags = item.ImageTags || {};

        if (tags.Primary) {
            imageId = item.Id;
            tag = tags.Primary;
        } else if (item.PrimaryImageTag) {
            imageId = item.Id;
            tag = item.PrimaryImageTag;
        } else if (item.AlbumId && item.AlbumPrimaryImageTag) {
            imageId = item.AlbumId;
            tag = item.AlbumPrimaryImageTag;
        } else if (item.SeriesId && item.SeriesPrimaryImageTag) {
            imageId = item.SeriesId;
            tag = item.SeriesPrimaryImageTag;
        } else if (item.ParentBackdropItemId && item.ParentBackdropImageTags
                   && item.ParentBackdropImageTags.length > 0) {
            imageId = item.ParentBackdropItemId;
            tag = item.ParentBackdropImageTags[0];
        }

        if (!tag || !imageId) {
            return "";
        }

        var wanted = Math.max(32, Math.min(2000, Number(size || imageSize) || 300));
        return apiRoot() + "/Items/" + encodeURIComponent(imageId) + "/Images/Primary"
            + "?maxWidth=" + wanted + "&maxHeight=" + wanted + "&quality=90"
            + "&tag=" + encodeURIComponent(tag)
            + "&api_key=" + encodeURIComponent(token);
    }

    function mediaSourceId(item) {
        if (item && item.MediaSources && item.MediaSources.length > 0
                && item.MediaSources[0].Id) {
            return item.MediaSources[0].Id;
        }
        return item ? item.Id : "";
    }

    function streamUrl(item, playSessionId) {
        if (!item || !connected || token.length === 0) {
            return "";
        }
        var kind = isAudio(item) ? "Audio" : "Videos";
        var query = {
            static: "true",
            MediaSourceId: mediaSourceId(item),
            DeviceId: effectiveDeviceId(),
            UserId: userId,
            PlaySessionId: playSessionId || "",
            api_key: token
        };
        return apiRoot() + "/" + kind + "/" + encodeURIComponent(item.Id) + "/stream?"
            + queryString(query);
    }

    // Used only if direct playback of an audio file is not supported by the
    // local Qt Multimedia codecs.
    function universalAudioUrl(item, playSessionId) {
        if (!item || !connected || token.length === 0) {
            return "";
        }
        var query = {
            UserId: userId,
            DeviceId: effectiveDeviceId(),
            MediaSourceId: mediaSourceId(item),
            PlaySessionId: playSessionId || "",
            MaxStreamingBitrate: 320000,
            Container: "mp3",
            AudioCodec: "mp3",
            TranscodingContainer: "mp3",
            TranscodingProtocol: "http",
            Context: "Streaming",
            api_key: token
        };
        return apiRoot() + "/Audio/" + encodeURIComponent(item.Id) + "/universal?"
            + queryString(query);
    }

    // ---------------------------------------------------------------------
    // Playback reporting
    // ---------------------------------------------------------------------

    function sessionBody(item, positionMs, playSessionId, paused) {
        return {
            ItemId: item.Id,
            MediaSourceId: mediaSourceId(item),
            PlaySessionId: playSessionId || "",
            PositionTicks: Math.max(0, Math.round((positionMs || 0) * 10000)),
            CanSeek: true,
            IsPaused: !!paused,
            IsMuted: false,
            PlayMethod: "DirectPlay",
            RepeatMode: "RepeatNone"
        };
    }

    function reportStart(item, positionMs, playSessionId, paused) {
        if (!connected || !item) {
            return;
        }
        request("POST", "/Sessions/Playing", null,
                sessionBody(item, positionMs, playSessionId, paused),
                function() {}, true);
    }

    function reportProgress(item, positionMs, playSessionId, paused) {
        if (!connected || !item) {
            return;
        }
        request("POST", "/Sessions/Playing/Progress", null,
                sessionBody(item, positionMs, playSessionId, paused),
                function() {}, true);
    }

    function reportStopped(item, positionMs, playSessionId) {
        if (!connected || !item) {
            return;
        }
        request("POST", "/Sessions/Playing/Stopped", null,
                sessionBody(item, positionMs, playSessionId, false),
                function() {}, true);
    }

    // ---------------------------------------------------------------------
    // Item helpers
    // ---------------------------------------------------------------------

    function isAudio(item) {
        if (!item) {
            return false;
        }
        return item.Type === "Audio" || item.Type === "AudioBook"
            || item.MediaType === "Audio";
    }

    function isVideo(item) {
        if (!item || isAudio(item)) {
            return false;
        }
        if (item.MediaType === "Video") {
            return true;
        }
        var type = item.Type || "";
        return type === "Movie" || type === "Episode" || type === "Video"
            || type === "MusicVideo" || type === "Trailer" || type === "Recording"
            || type === "Clip";
    }

    function isPlayable(item) {
        return isAudio(item) || isVideo(item);
    }

    function isBrowsable(item) {
        if (!item) {
            return false;
        }
        var type = item.Type || "";
        return type === "CollectionFolder" || type === "Folder" || type === "UserView"
            || type === "Series" || type === "Season" || type === "MusicAlbum"
            || type === "MusicArtist" || type === "Playlist" || type === "BoxSet";
    }

    function canOpen(item) {
        return isPlayable(item) || isBrowsable(item);
    }
}
