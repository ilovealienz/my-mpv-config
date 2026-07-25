-- ts-reconnect.lua
--
-- Auto-reconnect for live MPEG-TS streams over HTTP. When the stream ends,
-- drops, or stalls, mpv would otherwise quit, sit idle, or freeze on the last
-- frame forever. This holds the last frame and keeps reloading until playback
-- resumes — and crucially un-pauses afterwards, because a reconnect via
-- loadfile can otherwise leave mpv stuck paused (a well-known mpv-reload bug).
--
-- Only affects http/https URLs ending in .ts. Local files and other formats
-- behave normally, and your keep-open setting is restored for them.
--
-- NOTE: the cleaner first line of defence is ffmpeg's own reconnect_at_eof=1
-- (set via stream-lavf-o in mpv.conf — see the .conf example). That handles a
-- misread EOF seamlessly at the ffmpeg layer. This script is the fallback for
-- when that reconnect gives up entirely and a full reload is the only option.
--
-- Two independent triggers:
--   * EOF        — the stream reached its end / the server closed it
--   * stall      — the demuxer cache stopped receiving data (optional)
--
-- Options (~/.config/mpv/script-opts/ts-reconnect.conf):
--   retry_delay=3     seconds between reconnect attempts
--   max_retries=0     0 = forever; N = give up after N attempts
--   stall_timeout=0   0 = off; N = reload if the cache gets no data for N sec
--   osd=yes           show a brief "reconnecting…" message

local mp = require 'mp'
local msg = require 'mp.msg'
local options = require 'mp.options'

local o = {
    retry_delay = 3,
    max_retries = 0,
    stall_timeout = 0,
    osd = true,
}
options.read_options(o, "ts-reconnect")

local orig_keep_open = mp.get_property("keep-open") or "no"

local url = nil        -- current live .ts URL, or nil
local timer = nil      -- pending retry timer (one at a time)
local attempts = 0
local reloading = false -- true between our reload and playback resuming

-- stall tracking
local last_cache = -1
local last_change = 0

local function now() return mp.get_time() end

local function is_live_ts(u)
    if not u then return false end
    if not u:match("^https?://") then return false end
    local path = u:gsub("%?.*$", "")          -- drop query string
    return path:match("%.[tT][sS]$") ~= nil
end

local function cancel_timer()
    if timer then timer:kill(); timer = nil end
end

local function do_reload()
    if not url then return end
    attempts = attempts + 1
    reloading = true
    msg.info(("reconnecting to live stream (attempt %d)"):format(attempts))
    if o.osd then
        mp.osd_message(("reconnecting… (%d)"):format(attempts), o.retry_delay)
    end
    mp.commandv("loadfile", url, "replace")
end

local function schedule_retry()
    if not url then return end                -- not a live .ts
    if timer then return end                  -- already queued
    if o.max_retries > 0 and attempts >= o.max_retries then
        msg.warn(("giving up after %d attempts"):format(attempts))
        if o.osd then mp.osd_message("stream lost — giving up", 4) end
        return
    end
    timer = mp.add_timeout(o.retry_delay, function()
        timer = nil
        do_reload()
    end)
end

-- track the loaded file, manage keep-open ------------------------------------

mp.register_event("file-loaded", function()
    local u = mp.get_property("stream-open-filename") or mp.get_property("path")
    if is_live_ts(u) then
        url = u
        last_cache, last_change = -1, now()
        -- hold the last frame instead of quitting, so we can retry underneath
        mp.set_property("keep-open", "yes")
    else
        url = nil
        reloading = false
        cancel_timer()
        mp.set_property("keep-open", orig_keep_open)  -- don't affect normal files
    end
end)

-- once playback genuinely (re)starts, we're connected: reset and force-unpause
mp.register_event("playback-restart", function()
    if not url then return end
    attempts = 0
    last_change = now()
    if reloading then
        reloading = false
        -- THE fix for "it auto-pauses": a reconnect can land paused, so
        -- explicitly resume rather than waiting for the user to hit play.
        mp.set_property_bool("pause", false)
    end
end)

-- manual reload: bind a key in input.conf, e.g.
--   Ctrl+r  script-binding ts-reconnect/reload
-- Forces a fresh connection to the live edge, whether or not it's stalled.
mp.add_key_binding(nil, "reload", function()
    if not url then
        mp.osd_message("not a live .ts stream", 2)
        return
    end
    cancel_timer()
    attempts = 0
    do_reload()
end)

-- trigger 1: EOF (kept-open stream ended, or server closed the connection) ---

mp.observe_property("eof-reached", "bool", function(_, v)
    if v == true and url then schedule_retry() end
end)

mp.register_event("end-file", function(e)
    if e.reason ~= "eof" and e.reason ~= "error" then return end
    -- also cover a failed *initial* connection, where file-loaded never fired
    -- and url is still unset: fall back to the path mpv was trying to open.
    if not url then
        local p = mp.get_property("path")
        if is_live_ts(p) then url = p end
    end
    if url then schedule_retry() end
end)

-- trigger 2: stall — demuxer cache stopped advancing (optional) --------------

if o.stall_timeout > 0 then
    mp.observe_property("demuxer-cache-time", "number", function(_, v)
        if v and v ~= last_cache then
            last_cache = v
            last_change = now()
        end
    end)
    mp.add_periodic_timer(1, function()
        if not url or reloading or timer then return end
        -- only count it as stalled if playback is actually starved
        if mp.get_property_bool("paused-for-cache")
           and (now() - last_change) > o.stall_timeout then
            msg.info("cache stalled with no data")
            schedule_retry()
        end
    end)
end
