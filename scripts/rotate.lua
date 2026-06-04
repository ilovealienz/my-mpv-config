local mp = require "mp"

local function rotate(delta)
    local new = (mp.get_property_number("video-rotate", 0) + delta) % 360
    mp.set_property_number("video-rotate", new < 0 and new + 360 or new)
    mp.osd_message("Rotated: " .. new .. "°", 1.0)
end

mp.add_key_binding("Ctrl+r", "rotate_cw", function() rotate(90) end)
mp.add_key_binding("Ctrl+R", "rotate_ccw", function() rotate(-90) end)

