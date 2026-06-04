-- titles.lua
-- Custom window title for audio and video files with track-list parsing and periodic updates.

local mp = require 'mp'

-- Toggle for showing warnings about unknown file extensions
local show_unknown_extension_warnings = false

-- Reset audio filters for audio files
local reset_audio_filters = true

-- Define file extensions for audio and video
local media_exts = {
    video = { mp4 = true, mkv = true, avi = true, flv = true, mov = true },
    audio = { mp3 = true, m4a = true, flac = true, wav = true, wma = true, aac = true, dsd = true, dsf = true, mqa = true }
}

-- Periodic update timer handle
local update_timer = nil

-- Get playlist position and count
local function get_playlist_info()
    return tonumber(mp.get_property("playlist-pos-1") or "1"),
           tonumber(mp.get_property("playlist-count") or "1")
end

-- Format playlist position
local function format_playlist_position(pos, count)
    return string.format("(%02d/%02d)", pos, count)
end

-- Format optional metadata parts, skipping empty values
local function format_optional_parts(...)
    local parts = {}
    for _, part in ipairs({...}) do
        if part and part ~= "" then table.insert(parts, part) end
    end
    return table.concat(parts, ", ")
end

-- Extract file extension
local function get_file_extension(path)
    local ext = string.match(path, "%.([^.]+)$")
    return ext and string.lower(ext) or ""
end

-- Fetch audio details from track-list
local function get_audio_track_details()
    local codec_map = {
        -- Lossy
        mp3 = "MPEG", aac = "AAC", vorbis = "Vorbis", opus = "Opus",
        wma = "WMA", ac3 = "AC-3", eac3 = "E-AC-3", dts = "DTS",
        atrac = "ATRAC", mp2 = "MPEG Layer II",
        -- Lossless
        flac = "FLAC", alac = "ALAC", wav = "WAV", ape = "Monkey's Audio",
        tak = "TAK", tta = "TTA", dsd = "DSD", mlp = "MLP",
        truehd = "Dolby TrueHD",
        -- Other
        atrac3 = "ATRAC3", atrac9 = "ATRAC9", wv = "WavPack", shn = "Shorten",
        caf = "CAF", amr_nb = "AMR (Narrowband)", amr_wb = "AMR (Wideband)",
        unknown = "Unknown Format"
    }

    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" and track.selected then
            local codec = track.codec or "unknown"

            if codec:match("^pcm_") then
                codec = codec:gsub("pcm_", "PCM ("):gsub("_", " "):gsub("le$", "LE)"):gsub("be$", "BE)")
            elseif codec:match("^dsd_") then
                codec = "DSD"
            else
                codec = codec_map[codec] or codec
            end

            local formatted_bitrate
            if codec == "FLAC" then
                local samplerate = mp.get_property_number("audio-params/samplerate")
                local bits = tonumber(string.match(mp.get_property("audio-params/format") or "", "%d+"))
                if samplerate and bits then
                    formatted_bitrate = string.format("%dbit / %gkHz", bits, samplerate / 1000)
                else
                    formatted_bitrate = "unknown"
                end
            else
                local bitrate = track["demux-bitrate"] or track["audio-bitrate"]
                if bitrate then
                    formatted_bitrate = bitrate > 1000000
                        and string.format("%.3f Mbps", bitrate / 1000000)
                        or  string.format("%.0f kbps", bitrate / 1000)
                else
                    formatted_bitrate = "unknown bitrate"
                end
            end

            mp.msg.info(string.format("Audio details: %s, %s", codec, formatted_bitrate))
            return string.format("%s, %s", codec, formatted_bitrate)
        end
    end
    return nil
end

-- Set title for audio files
local function set_audio_title(playlist_pos, playlist_count)
    local track         = mp.get_property("metadata/by-key/track") or ""
    local media_title   = mp.get_property("media-title") or ""
    local artist        = mp.get_property("metadata/by-key/artist") or ""
    local album         = mp.get_property("metadata/by-key/album") or ""
    local date          = mp.get_property("metadata/by-key/date") or ""
    local path          = mp.get_property("path") or ""
    local ext           = get_file_extension(path)
    local audio_details = get_audio_track_details()

    local track_number  = tonumber(track) and string.format("%02d", tonumber(track)) or track
    local optional_info = format_optional_parts(album, date, audio_details, ext)

    local title
    if ext == "m4a" then
        title = string.format("%s %s - %s%s [%s] - mpv",
            format_playlist_position(playlist_pos, playlist_count),
            artist,
            track_number ~= "" and track_number .. " - " or "",
            media_title,
            format_optional_parts(album, date, audio_details))
    else
        title = string.format("%s %s - %s%s [%s] - mpv",
            format_playlist_position(playlist_pos, playlist_count),
            artist,
            track_number ~= "" and track_number .. " - " or "",
            media_title,
            optional_info)
    end

    mp.set_property("title", title)

    if reset_audio_filters then
        mp.set_property("af", "")
    end
end

-- Set title for video files
local function set_video_title(playlist_pos, playlist_count)
    local filename_no_ext = mp.get_property("filename/no-ext") or ""
    local chapter_title   = mp.get_property("chapter-metadata/by-key/title") or ""

    local title = string.format("%s %s%s - mpv",
        format_playlist_position(playlist_pos, playlist_count),
        filename_no_ext,
        chapter_title ~= "" and " [" .. chapter_title .. "]" or "")

    mp.set_property("title", title)
end

-- Determine media type and set appropriate title
local function set_title()
    local path = mp.get_property("path", "")
    local ext  = get_file_extension(path)

    if ext == "" then
        if show_unknown_extension_warnings then
            mp.msg.warn("Unable to determine file extension for path: " .. path)
        end
        return
    end

    local playlist_pos, playlist_count = get_playlist_info()

    if media_exts.video[ext] then
        set_video_title(playlist_pos, playlist_count)
    elseif media_exts.audio[ext] then
        set_audio_title(playlist_pos, playlist_count)
    else
        if show_unknown_extension_warnings then
            mp.msg.warn("Unknown file extension: " .. ext)
        end
    end
end

-- Register events
mp.register_event("file-loaded", function()
    if update_timer then
        update_timer:kill()
        update_timer = nil
    end

    set_title()

    update_timer = mp.add_periodic_timer(3, set_title)
end)