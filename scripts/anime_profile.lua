-- anime_profile.lua

mp.add_key_binding("ctrl+alt+a", "anime-profile", function()
    -- Reset subs
    mp.set_property("sub-scale", "1.0")
    mp.set_property("sub-pos", "100")

    -- If over 480p, trigger Anime4K HQ (CTRL+1)
    local h = mp.get_property_number("video-params/h")
    if h and h > 480 then
        mp.commandv("keypress", "CTRL+1")
        mp.osd_message("Anime profile: subs reset + Anime4K HQ")
    else
        mp.osd_message("Anime profile: subs reset")
    end
end)
