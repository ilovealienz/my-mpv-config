local mp = require 'mp'
local options = require 'mp.options'

local opts = {
    quietness = -30,
    duration = 0.5,
    max_speed = 100,
    stream_max_speed = 30,
    stream_min_speed = 2,
    chapter_lookahead = 10,
    max_skip = 150,
}
options.read_options(opts, 'skip-intro')

local chapter_patterns = {
    '^op$', '^op[%s%d%-:]', 'opening', '^ncop', '^intro', 'intro$',
    'title sequence', 'main title', 'theme song',
    '^ed$', '^ed[%s%d%-:]', 'ending', '^nced', '^outro', 'outro$', 'credits',
    'preview', 'next episode', 'next time', 'recap', 'previously on',
}

local skipping = false
local start_time = 0
local saved_speed = 1
local saved_mute = false
local saved_cache_pause = nil
local speed_timer = nil
local added_vf = false
local on_silence

local function is_skippable(title)
    if not title then return false end
    title = title:lower()
    for _, p in ipairs(chapter_patterns) do
        if title:find(p) then return true end
    end
    return false
end

local function chapter_target()
    local now = mp.get_property_number('time-pos')
    if not now then return nil end
    local chapters = mp.get_property_native('chapter-list') or {}
    local duration = mp.get_property_number('duration')
    for i, c in ipairs(chapters) do
        local stop = chapters[i + 1] and chapters[i + 1].time or duration
        local current = c.time <= now and stop and now < stop
        local upcoming = c.time > now and c.time <= now + opts.chapter_lookahead
        if stop and (current or upcoming) and is_skippable(c.title) then
            return stop
        end
    end
end

local function is_stream()
    return mp.get_property_bool('demuxer-via-network', false)
end

local function stop_skip()
    if not skipping then return end
    skipping = false
    mp.unobserve_property(on_silence)
    if speed_timer then
        speed_timer:kill()
        speed_timer = nil
    end
    mp.commandv('af', 'remove', '@skipsilence')
    if added_vf then
        mp.commandv('vf', 'remove', '@skipblack')
        added_vf = false
    end
    mp.set_property_bool('mute', saved_mute)
    mp.set_property_number('speed', saved_speed)
    if saved_cache_pause ~= nil then
        mp.set_property_bool('cache-pause', saved_cache_pause)
        saved_cache_pause = nil
    end
end

on_silence = function(_, meta)
    if not skipping or type(meta) ~= 'table' then return end
    local t = tonumber(meta['lavfi.silence_start'])
    if not t or t < start_time + 1 then return end
    stop_skip()
    mp.set_property_number('time-pos', t)
end

local function tick()
    if mp.get_property_bool('eof-reached', false) then
        stop_skip()
        return
    end
    local now = mp.get_property_number('time-pos')
    if now and now > start_time + opts.max_skip then
        stop_skip()
        mp.set_property_number('time-pos', start_time)
        mp.osd_message('No silence found')
        return
    end
    if is_stream() then
        local cache = mp.get_property_number('demuxer-cache-duration', 0)
        local speed = math.floor(math.max(opts.stream_min_speed, math.min(opts.stream_max_speed, cache / 2)))
        if speed ~= mp.get_property_number('speed') then
            mp.set_property_number('speed', speed)
        end
    end
end

local function start_skip()
    skipping = true
    start_time = mp.get_property_number('time-pos', 0)
    saved_speed = mp.get_property_number('speed', 1)
    saved_mute = mp.get_property_bool('mute', false)

    mp.commandv('af', 'pre', '@skipsilence:lavfi=[silencedetect=noise=' ..
        opts.quietness .. 'dB:d=' .. opts.duration .. ']')
    local w = mp.get_property_number('width', 0)
    local h = mp.get_property_number('height', 0)
    if w > 0 and h > 0 then
        mp.commandv('vf', 'add', '@skipblack:lavfi=[nullsink,color=c=black:s=' .. w .. 'x' .. h .. ']')
        added_vf = true
    end
    mp.observe_property('af-metadata/skipsilence', 'native', on_silence)

    mp.set_property_bool('pause', false)
    mp.set_property_bool('mute', true)
    if is_stream() then
        -- lower speed instead of pausing when the cache runs low
        saved_cache_pause = mp.get_property_bool('cache-pause', true)
        mp.set_property_bool('cache-pause', false)
        mp.set_property_number('speed', opts.stream_min_speed)
    else
        mp.set_property_number('speed', opts.max_speed)
    end
    speed_timer = mp.add_periodic_timer(0.25, tick)
end

local function keypress()
    if skipping then
        stop_skip()
        mp.set_property_number('time-pos', start_time)
        return
    end
    local target = chapter_target()
    if target then
        mp.set_property_number('time-pos', target)
        return
    end
    start_skip()
end

mp.add_key_binding('Shift+Tab', 'skip-key', keypress)
mp.register_event('end-file', stop_skip)
