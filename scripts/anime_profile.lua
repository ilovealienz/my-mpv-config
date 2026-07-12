-- anime_profile.lua

local options = require "mp.options"

local o = {
    enabled = true,   -- disable the whole script
    shaders = true,   -- disable just the Anime4K shader application
}
options.read_options(o, "anime_profile")

local anime_profile_applied = false

local function apply_anime_profile()
    if not o.enabled then
        mp.osd_message("Anime profile: disabled")
        return
    end

    -- Reset subs
    mp.set_property("sub-scale", "1.0")
    mp.set_property("sub-pos", "100")

    -- If over 480p, apply Anime4K HQ via shaders.lua
    local h = mp.get_property_number("video-params/h")
    if o.shaders and h and h > 480 then
        mp.commandv("script-message", "apply-shader-family", "CTRL+1", "Anime profile loaded")
    else
        mp.osd_message("Anime profile: subs reset")
    end
end

local function is_anime_path(path)
    if not path then return false end
    return path:lower():find("/anime/") ~= nil
end

-- Auto-apply once on first file load
mp.register_event("file-loaded", function()
    if not o.enabled then return end
    local path = mp.get_property("path")
    if not anime_profile_applied and is_anime_path(path) then
        apply_anime_profile()
        anime_profile_applied = true
    end
end)

-- Manual trigger still available
mp.add_key_binding("ctrl+alt+a", "anime-profile", apply_anime_profile)