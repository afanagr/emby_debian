/*
 * SPDX-FileCopyrightText: 2026 Emby Plasma contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

.pragma library

function pad2(value) {
    var number = Math.max(0, Math.floor(Number(value) || 0));
    return number < 10 ? "0" + number : String(number);
}

function ticksToMs(ticks) {
    return Math.max(0, Math.round((Number(ticks) || 0) / 10000));
}

function formatMs(milliseconds) {
    var total = Math.max(0, Math.floor((Number(milliseconds) || 0) / 1000));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var seconds = total % 60;
    if (hours > 0) {
        return hours + ":" + pad2(minutes) + ":" + pad2(seconds);
    }
    return minutes + ":" + pad2(seconds);
}

function formatTicks(ticks) {
    return formatMs(ticksToMs(ticks));
}

function joinNonEmpty(parts, separator) {
    var result = [];
    for (var i = 0; i < parts.length; ++i) {
        if (parts[i] !== undefined && parts[i] !== null && String(parts[i]).length > 0) {
            result.push(String(parts[i]));
        }
    }
    return result.join(separator || " · ");
}

function artistsText(item) {
    if (!item) {
        return "";
    }
    if (item.Artists && item.Artists.length > 0) {
        return item.Artists.join(", ");
    }
    if (item.AlbumArtist) {
        return item.AlbumArtist;
    }
    if (item.AlbumArtists && item.AlbumArtists.length > 0) {
        var names = [];
        for (var i = 0; i < item.AlbumArtists.length; ++i) {
            if (item.AlbumArtists[i].Name) {
                names.push(item.AlbumArtists[i].Name);
            }
        }
        return names.join(", ");
    }
    return "";
}

function trackCountText(count) {
    var n = Math.max(0, Math.floor(Number(count) || 0));
    var mod10 = n % 10;
    var mod100 = n % 100;
    var word = "треков";
    if (mod10 === 1 && mod100 !== 11) {
        word = "трек";
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
        word = "трека";
    }
    return n + " " + word;
}

function episodeCode(item) {
    if (!item) {
        return "";
    }
    var code = "";
    if (item.ParentIndexNumber !== undefined && item.ParentIndexNumber !== null) {
        code += "S" + pad2(item.ParentIndexNumber);
    }
    if (item.IndexNumber !== undefined && item.IndexNumber !== null) {
        code += "E" + pad2(item.IndexNumber);
    }
    return code;
}

function itemSubtitle(item) {
    if (!item) {
        return "";
    }

    var type = item.Type || "";
    if (type === "Audio" || type === "AudioBook") {
        var bits = [artistsText(item)];
        if (item.Album && item.Album !== artistsText(item)) {
            bits.push(item.Album);
        }
        return joinNonEmpty(bits);
    }
    if (type === "MusicAlbum") {
        return joinNonEmpty([artistsText(item),
                             item.ProductionYear,
                             item.ChildCount ? trackCountText(item.ChildCount) : ""]);
    }
    if (type === "MusicArtist") {
        return "Исполнитель";
    }
    if (type === "Episode") {
        return joinNonEmpty([item.SeriesName, episodeCode(item)]);
    }
    if (type === "Season") {
        return joinNonEmpty([item.SeriesName,
                             item.IndexNumber !== undefined ? "Сезон " + item.IndexNumber : ""]);
    }
    if (type === "Series") {
        return joinNonEmpty([item.ProductionYear,
                             item.ChildCount ? "Сезонов: " + item.ChildCount : ""]);
    }
    if (type === "Movie" || type === "Video" || type === "MusicVideo"
            || type === "Trailer" || type === "Recording" || type === "Clip") {
        return joinNonEmpty([item.ProductionYear, item.OfficialRating]);
    }
    if (type === "Playlist") {
        return joinNonEmpty([item.ChildCount ? trackCountText(item.ChildCount) : "",
                             "Плейлист"]);
    }
    if (type === "BoxSet") {
        return "Коллекция";
    }
    if (type === "Folder") {
        return "Папка";
    }
    if (type === "CollectionFolder") {
        return item.CollectionType === "music" ? "Музыка"
            : item.CollectionType === "movies" ? "Фильмы"
            : item.CollectionType === "tvshows" ? "Сериалы"
            : "";
    }
    return "";
}

function itemIcon(item) {
    if (!item) {
        return "media-playback-start";
    }
    var type = item.Type || "";
    if (type === "Audio" || type === "AudioBook" || type === "MusicArtist") {
        return "audio-x-generic";
    }
    if (type === "MusicAlbum" || type === "Playlist") {
        return "media-optical";
    }
    if (type === "Movie" || type === "Video" || type === "MusicVideo"
            || type === "Trailer" || type === "Recording" || type === "Clip") {
        return "video-x-generic";
    }
    if (type === "Series" || type === "Season" || type === "Episode") {
        return "video-television";
    }
    if (type === "Folder" || type === "CollectionFolder" || type === "BoxSet") {
        return "folder";
    }
    return "media-playback-start";
}

function libraryIcon(view) {
    if (!view) {
        return "folder";
    }
    var type = view.CollectionType || "";
    if (type === "music") {
        return "audio-x-generic";
    }
    if (type === "movies") {
        return "video-x-generic";
    }
    if (type === "tvshows") {
        return "video-television";
    }
    if (type === "musicvideos") {
        return "video-x-generic";
    }
    if (type === "homevideos") {
        return "camera-video";
    }
    if (type === "photos") {
        return "image-x-generic";
    }
    if (type === "books") {
        return "x-office-document";
    }
    if (type === "playlists") {
        return "view-media-playlist";
    }
    return "folder";
}
