local mp = require 'mp'

-- Function to handle Media_Next key
local function handle_media_next()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    if playlist_count == 1 or mp.get_property_bool("eof-reached", false) then
        -- Restart the playlist if there's only one video or EOF is reached
        mp.command("playlist-play-index 0")
        
        -- Give mpv a moment to update and then start playing
        mp.add_timeout(0.1, function()
            mp.set_property("pause", "no")  -- Unpause playback to start playing
            mp.osd_message("Playlist restarted and playing")
        end)
    else
        -- Pass through to default behavior if not at EOF
        mp.command("playlist-next")
        mp.set_property("pause", "no")  -- Unpause to start playing
    end
end

-- Bind the "mouse media next" key to the function
mp.add_key_binding("NEXT", "custom_next", handle_media_next)
