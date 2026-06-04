local mp = require 'mp'
local function show_end_time()
    local total_seconds = mp.get_property_number("duration", 0) - mp.get_property_number("playback-time", 0)
    if total_seconds > 0 then
        local current_time = os.time()
        local end_time = os.date("*t", current_time + total_seconds)
        local end_time_str = string.format("%02d:%02d:%02d", end_time.hour, end_time.min, end_time.sec)
        mp.osd_message("Playback ends at " .. end_time_str .. " (24h)")
    else
        mp.osd_message("No media loaded or invalid duration")
    end
end

mp.add_key_binding("MBTN_RIGHT", "show-end-time", show_end_time)
