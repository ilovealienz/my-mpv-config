-- auto-image-playlist.lua
-- Automatically adds all images (including animated formats like GIFs) in the current directory to the playlist in alphabetical order,
-- and loops animated images until manually advancing to the next file.

local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- Supported image extensions, including animated formats like GIF and APNG
local image_extensions = {
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp', 'tiff', 'tif', 'apng'
}

-- List of animated formats to loop
local animated_formats = {
    'gif', 'apng'
}

-- Function to check if a file is an image
local function is_image_file(file)
    local ext = file:match("^.+%.([a-zA-Z0-9]+)$")
    if not ext then return false end
    ext = ext:lower()
    for _, v in ipairs(image_extensions) do
        if ext == v then
            return true
        end
    end
    return false
end

-- Function to check if a file is an animated image
local function is_animated_file(file)
    local ext = file:match("^.+%.([a-zA-Z0-9]+)$")
    if not ext then return false end
    ext = ext:lower()
    for _, v in ipairs(animated_formats) do
        if ext == v then
            return true
        end
    end
    return false
end

-- Add image files to the playlist
local function add_images_to_playlist(directory, current_file)
    -- Check if the playlist already contains items
    local playlist_count = mp.get_property_number("playlist-count", 0)
    if playlist_count > 1 then
        msg.info("Images already added to the playlist. Skipping re-adding.")
        return
    end

    local dir_list = utils.readdir(directory, "files")
    if not dir_list then
        msg.error("Could not read directory: " .. directory)
        return
    end

    local files = {}

    -- Filter and sort files
    for _, file in ipairs(dir_list) do
        if is_image_file(file) then
            table.insert(files, file)
        end
    end
    table.sort(files)

    -- Add files to the playlist
    local current_file_found = false
    for _, file in ipairs(files) do
        local full_path = utils.join_path(directory, file)
        if full_path == current_file then
            current_file_found = true
        end
        mp.commandv("loadfile", full_path, current_file_found and "append-play" or "append")
    end
end

-- Event handler for when a file is loaded
mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if not path then
        return
    end

    local directory, filename = utils.split_path(path)
    if is_image_file(filename) then
        msg.info("Image detected. Adding other images (including animations) from the directory to the playlist.")
        add_images_to_playlist(directory, path)

        -- Check if the file is animated and enable looping for it only
        if is_animated_file(filename) then
            msg.info("Animated file detected. Enabling loop.")
            mp.set_property("loop-file", "inf")
        else
            -- Ensure non-animated files do not loop
            mp.set_property("loop-file", "no")
        end

        -- Ensure playlist itself does not loop
        mp.set_property("loop-playlist", "no")
    end
end)
