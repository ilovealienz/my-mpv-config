-- anime_profile.lua

local function apply_anime_profile()
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
end

local function is_anime_path(path)
    if not path then return false end
    -- Match either .../Anime/... or .../Anime/Dual Audio/...
    return path:lower():find("/anime/") ~= nil
end

-- Auto-apply on file load
mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if is_anime_path(path) then
        apply_anime_profile()
    end
end)

-- Manual trigger still available
mp.add_key_binding("ctrl+alt+a", "anime-profile", apply_anime_profile)