local utils = require "mp.utils"

-- Get filename (name-based sorting)
local function getName()
    local playlist = mp.get_property_native('playlist')
    local dt = {}
    for i = 1, #playlist do
        table.insert(dt, {filename = playlist[i].filename, data = playlist[i].filename:lower()})
    end
    return dt
end

-- Get last modified time (date-based sorting)
local function getDate()
    local playlist = mp.get_property_native('playlist')
    local dt = {}
    for i = 1, #playlist do
        local data = nil
        local fi = utils.file_info(playlist[i].filename)
        if(fi == nil) then
            data = 0
        else
            data = fi.mtime
        end
        table.insert(dt, {filename = playlist[i].filename, data = data})
    end
    return dt
end

-- Get file size (size-based sorting)
local function getSize()
    local playlist = mp.get_property_native('playlist')
    local dt = {}
    for i = 1, #playlist do
        local data = nil
        local fi = utils.file_info(playlist[i].filename)
        if(fi == nil) then
            data = 0
        else
            data = fi.size
        end
        table.insert(dt,  {filename = playlist[i].filename, data = data})
    end
    return dt
end

-- Get media duration (duration-based sorting)
local function getDuration()
    local playlist = mp.get_property_native('playlist')
    local dt = {}
    for i = 1, #playlist do
        local data = mp.get_property_native("playlist/" .. (i-1) .. "/duration")
        table.insert(dt, {filename = playlist[i].filename, data = data})
    end
    return dt
end

-- Sort function
local function sort(dt, asc)
    if(asc == nil or asc == "asc" or asc == "") then
        table.sort(dt, function(a, b) return a.data < b.data end)
    else
        table.sort(dt, function(a, b) return a.data > b.data end)
    end
end

-- Main sorting function that updates the playlist
local function main(type, asc)
    local dt = nil
    if(type == nil) then type = "name" end
    if(asc == nil) then asc = "asc" end

    -- Get the current playing file's filename
    local current_file = mp.get_property("filename")

    -- Choose sorting method based on type
    if(type == "date") then
        dt = getDate()
    elseif(type == "size") then
        dt = getSize()
    elseif(type == "duration") then
        dt = getDuration()
    else
        dt = getName()
    end

    -- Sort the playlist according to the selected method
    sort(dt, asc)

    -- Clear the current playlist and reload sorted files
    mp.commandv('playlist-clear')
    for i, n in ipairs(dt) do
        if(i == 1) then
            mp.commandv('loadfile', n.filename, 'replace')  -- Replace current file
        else
            mp.commandv('loadfile', n.filename, 'append')  -- Append remaining files
        end
    end

    -- Find the new position of the currently playing file
    for i, n in ipairs(dt) do
        if n.filename == current_file then
            mp.set_property("playlist-pos", i - 1)  -- Set position to the current file
            break
        end
    end

    -- Show a message with the current sort method
    mp.osd_message("Playlist Sort: " .. type .. " " .. asc)
end

-- Register the script to be triggered by "playlist-sort" message
mp.register_script_message("playlist-sort", main)

-- Bind Alt+P to toggle sorting and cycle through methods
local state = 0
local sorting_method = "name"
local sorting_order = "asc"
local last_press_time = 0  -- Track the last time Alt+P was pressed
local idle_time = 1  -- Time (in seconds) before applying the last sorting choice
local key_pressed = false  -- Flag to track if Alt+P was pressed
local press_time = 0  -- Timestamp of when Alt+P was last pressed

-- Function to toggle between sorting methods
local function toggle_sorting()
    -- Update the last press time
    press_time = mp.get_time()

    -- Toggle between different sorting options
    if state == 0 then
        sorting_method = "name"
        sorting_order = "asc"
        mp.osd_message("Sorting by name (ascending)")
        state = 1
    elseif state == 1 then
        sorting_method = "size"
        sorting_order = "desc"
        mp.osd_message("Sorting by size (descending)")
        state = 2
    elseif state == 2 then
        sorting_method = "date"
        sorting_order = "desc"
        mp.osd_message("Sorting by date (descending)")
        state = 3
    elseif state == 3 then
        sorting_method = "duration"
        sorting_order = "desc"
        mp.osd_message("Sorting by duration (descending)")
        state = 4
    elseif state == 4 then
        sorting_method = "name"
        sorting_order = "desc"
        mp.osd_message("Sorting by name (descending)")
        state = 0
    end

    -- Wait for idle time before applying the sorting, if no more keypresses
    mp.add_timeout(idle_time, function()
        if mp.get_time() - press_time >= idle_time then
            -- Apply the last chosen sorting method after waiting
            main(sorting_method, sorting_order)
        end
    end)
end

-- Bind Alt+P to toggle sorting
mp.add_key_binding("alt+p", "cycle_sorting", toggle_sorting)
