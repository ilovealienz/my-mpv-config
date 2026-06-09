-- shaders.lua

local mp = require 'mp'

local separator = package.config:sub(1,1) == '\\' and ";" or ":"

local A4K  = "~~/shaders/Anime4K/"
local V2   = "~~/shaders/Ani4Kv2/"
local SD   = "~~/shaders/AniSD/"
local FSRC = "~~/shaders/FSRCNNX/"

local CLAMP   = A4K .. "Anime4K_Clamp_Highlights.glsl"
local DOWN_X2 = A4K .. "Anime4K_AutoDownscalePre_x2.glsl"
local DOWN_X4 = A4K .. "Anime4K_AutoDownscalePre_x4.glsl"
local UP_VL   = A4K .. "Anime4K_Upscale_CNN_x2_VL.glsl"
local UP_M    = A4K .. "Anime4K_Upscale_CNN_x2_M.glsl"

local families = {
    ["CTRL+1"] = {
        label = "Anime4K HQ",
        presets = {
            { name = "Mode A+A", paths = {
                CLAMP,
                A4K.."Anime4K_Restore_CNN_VL.glsl",
                UP_VL,
                A4K.."Anime4K_Restore_CNN_M.glsl",
                DOWN_X2, DOWN_X4, UP_M
            }},
            { name = "Mode B+B", paths = {
                CLAMP,
                A4K.."Anime4K_Restore_CNN_Soft_VL.glsl",
                UP_VL,
                DOWN_X2, DOWN_X4,
                A4K.."Anime4K_Restore_CNN_Soft_M.glsl",
                UP_M
            }},
            { name = "Mode C+A", paths = {
                CLAMP,
                A4K.."Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
                DOWN_X2, DOWN_X4,
                A4K.."Anime4K_Restore_CNN_M.glsl",
                UP_M
            }},
        },
    },
    ["CTRL+2"] = {
        label = "Anime4K",
        presets = {
            { name = "Mode A", paths = {
                CLAMP,
                A4K.."Anime4K_Restore_CNN_VL.glsl",
                UP_VL,
                DOWN_X2, DOWN_X4, UP_M
            }},
            { name = "Mode B", paths = {
                CLAMP,
                A4K.."Anime4K_Restore_CNN_Soft_VL.glsl",
                UP_VL,
                DOWN_X2, DOWN_X4, UP_M
            }},
            { name = "Mode C", paths = {
                CLAMP,
                A4K.."Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
                DOWN_X2, DOWN_X4, UP_M
            }},
        },
    },
    ["CTRL+3"] = {
        label = "Ani4Kv2",
        presets = {
            { name = "Ani4Kv2", paths = {
                V2.."Ani4Kv2_ArtCNN_C4F32_i2.glsl"
            }},
            { name = "Ani4Kv2 CMP", paths = {
                V2.."Ani4Kv2_ArtCNN_C4F32_i2_CMP.glsl"
            }},
        },
    },
    ["CTRL+4"] = {
        label = "AniSD",
        presets = {
            { name = "AniSD", paths = {
                SD.."AniSD_ArtCNN_C4F32_i4.glsl"
            }},
            { name = "AniSD CMP", paths = {
                SD.."AniSD_ArtCNN_C4F32_i4_CMP.glsl"
            }},
        },
    },
    ["CTRL+5"] = {
        label = "FSRCNNX",
        presets = {
            { name = "x2 8-0-4-1",  paths = { FSRC.."FSRCNNX_x2_8-0-4-1.glsl"  }},
            { name = "x2 16-0-4-1", paths = { FSRC.."FSRCNNX_x2_16-0-4-1.glsl" }},
        },
    },
}

local state = {}

local function clear_shaders(silent)
    mp.commandv("change-list", "glsl-shaders", "clr", "")
    for k in pairs(state) do state[k] = nil end
    if not silent then mp.osd_message("Shaders cleared") end
end

mp.add_key_binding("CTRL+0", "shaders_clear", clear_shaders)

for key, family in pairs(families) do
    local binding_id = "shader_" .. key:gsub("CTRL%+", "")

    mp.add_key_binding(key, binding_id, function()
        local presets = family.presets
        local current = state[key]

        if current == nil then
            for k in pairs(state) do state[k] = nil end
            mp.commandv("change-list", "glsl-shaders", "clr", "")
            state[key] = 1
        elseif current >= #presets then
            clear_shaders(true)
            mp.osd_message(family.label .. ": off")
            return
        else
            state[key] = current + 1
        end

        local preset = presets[state[key]]
        local path_str = table.concat(preset.paths, separator)
        mp.commandv("change-list", "glsl-shaders", "set", path_str)
        mp.osd_message(family.label .. " [" .. state[key] .. "/" .. #presets .. "]: " .. preset.name)
    end)
end

mp.register_script_message("apply-shader-family", function(key, osd_override)
    local family = families[key]
    if not family then return end

    for k in pairs(state) do state[k] = nil end
    mp.commandv("change-list", "glsl-shaders", "clr", "")
    state[key] = 1

    local preset = family.presets[1]
    local path_str = table.concat(preset.paths, separator)
    mp.commandv("change-list", "glsl-shaders", "set", path_str)

    if osd_override and osd_override ~= "" then
        mp.osd_message(osd_override)
    else
        mp.osd_message(family.label .. " [1/" .. #family.presets .. "]: " .. preset.name)
    end
end)