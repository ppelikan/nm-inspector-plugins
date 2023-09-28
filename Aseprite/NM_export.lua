--[[
    Normal Map Inspector add-on script for Aseprite 
    Copyright (C) 2023 ppelikan

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

-- global constants
local DISABLED_LAYER_LABEL = "- none -"
local SUBLAYER_LAYER_PREFIX = "  "

-- global variables
local config_dialog
local spr
local layer_diff
local layer_norm
local layer_spec
local groups_supported

-- ==========================================================================

-- stop all activity and exit
local function finish()
    if config_dialog ~= nil then config_dialog:close() end
    config_dialog = nil
    spr = nil
    layer_diff = nil
    layer_norm = nil
    layer_spec = nil
end

-- returns an existing layer name that has it's name similar to the given string name
-- or returns an empty string, when no layer has given string name in it
-- if there are groups, then sublayers are never searched
local function find_layer_name(name, equal)
    local sprite = app.activeSprite
    for _ , layer in ipairs(sprite.layers) do
        if layer.name:lower():find( name:lower(), 1, true ) then
            if equal then
                return layer.name
            end
        elseif not equal then
            return layer.name
        end
    end
    return ""
end

-- returns a layer object of the layer with given string name
-- or returns nil, when no layer was selected
local function get_layer(name)
    if name == DISABLED_LAYER_LABEL then
        return nil
    end
    local sprite = app.activeSprite
    for _, layer in ipairs(sprite.layers) do
      if layer.name == name then 
         return layer
      elseif layer.layers ~= nil then
        -- layer is group of layers
         for _, l in ipairs(layer.layers) do
            if SUBLAYER_LAYER_PREFIX..l.name == name then 
                return l
            end
         end
      end
    end
end

-- returns proper filename for given layer
local function make_export_fname(layer)
    if layer == nil then
        return ""
    end 
    local fname = app.fs.filePath(spr.filename) .. app.fs.pathSeparator .. app.fs.fileTitle(spr.filename) .. "_"
    return fname .. layer.name .. ".png"
end

-- saves given layer as fname
local function export_layer(layer, fname)
    if layer == nil then
        return
    end 
    app.command.ExportSpriteSheet {
        ui=false,
        askOverwrite=false,
        layer=layer.name,
        textureFilename = fname,
        openGenerated=false,
    }
    
    -- workaround to wait until the temporary export sprite closes
    while spr ~= app.activeSprite do
    end
end

-- OK button clicked, expot files
local function start()
    -- assign selected layers
    layer_diff = get_layer(config_dialog.data.diff_layer)
    layer_norm = get_layer(config_dialog.data.norm_layer)
    layer_spec = get_layer(config_dialog.data.spec_layer)

    fname_diff = make_export_fname(layer_diff)
    fname_norm = make_export_fname(layer_norm)
    fname_spec = make_export_fname(layer_spec)

    local proceed = true

    local txtn = {}
    if app.fs.isFile(fname_diff) then
        table.insert(txtn, fname_diff)
    end
    if app.fs.isFile(fname_norm) then
        table.insert(txtn, fname_norm)
    end
    if app.fs.isFile(fname_spec) then
        table.insert(txtn, fname_spec)
    end

    if #txtn > 0 then
        local result = app.alert{ title="Warning!",
                                  text={"Following files already exist:", table.unpack(txtn)},
                                  buttons={"Overwrite", "Cancel"}}
        if result == 2 then
            proceed = false
        end
    end

    if proceed == true then
        export_layer(layer_diff, fname_diff)
        export_layer(layer_norm, fname_norm)
        export_layer(layer_spec, fname_spec)
    end

    finish()
end

-- returns true if the string s is empty
local function isempty(s)
    return s == nil or s == ''
end

-- Script execution start ===================================================

if app.version.prereleaseLabel == "alpha" or app.version.prereleaseLabel == "beta" then
    app.alert{title="Warning!", text="This script may encounter errors with Asperite in beta versions."}
end
if app.version < Version("1.2.40") then
    app.alert{title="Warning!", text="This script may encounter errors with outdated Aseprite versions. Please update."}
end

groups_supported = true
found_groups = false
if app.version < Version("1.3-rc2") then
    groups_supported = false
    SUBLAYER_LAYER_PREFIX = ""
end

spr = app.activeSprite

if spr == nil then
    app.alert{title="Error!", text="Not found any active projects."}
    return
end

if isempty(spr.filename) then
    app.alert{title="Error!", text="Please save your project before exporting."}
    return
end

layer_names = {DISABLED_LAYER_LABEL}
for _,layer in ipairs(spr.layers) do
    if layer.layers ~= nil then
        -- layer is group of layers
        found_groups = true
        if groups_supported == true then
            table.insert(layer_names, layer.name)
        end
        for _,l in ipairs(layer.layers) do
            table.insert(layer_names, SUBLAYER_LAYER_PREFIX..l.name)
        end
    else
        table.insert(layer_names, layer.name)
    end
end

-- ==========================================================================
-- this is just some garbage logic for layer auto selection in comboboxes 
local tmp_diff_name = find_layer_name("diff", true)
local tmp_norm_name = find_layer_name("norm", true)
local tmp_spec_name = find_layer_name("spec", true)
local cnt = #spr.layers
if cnt == 1 then
    tmp_diff_name = spr.layers[1].name
    tmp_norm_name = ""
elseif cnt <=3 then
    if isempty(tmp_diff_name) and not isempty(tmp_norm_name) then
        tmp_diff_name = find_layer_name("norm", false)
    elseif not isempty(tmp_diff_name) and isempty(tmp_norm_name) then
        tmp_norm_name = find_layer_name("diff", false)
    end
end
if cnt <= 2 then
    tmp_spec_name = ""
end
-- ==========================================================================

finish_fnc = finish
config_dialog = Dialog{title="NM Inspector - export layers"}
if groups_supported == false and found_groups == true then
    config_dialog:label{ label="Warning!", text="Layer groups are unsupported." }
    config_dialog:label{ label="", text="Please update Aseprite to version 1.3" }
    config_dialog:separator{}
end

config_dialog:combobox{ id="diff_layer",
              label="Diffuse texture layer: ",
              options=layer_names,
              option=tmp_diff_name}
config_dialog:combobox{ id="norm_layer",
              label="Normal map layer: ",
              options=layer_names,
              option=tmp_norm_name}
config_dialog:combobox{ id="spec_layer",
              label="Specular map layer: ",
              options=layer_names,
              option=tmp_spec_name}
config_dialog:button{ text="OK", onclick=start}
config_dialog:button{ text="Cancel", onclick=finish}
config_dialog:show{ wait=true }
