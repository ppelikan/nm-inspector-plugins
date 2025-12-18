--[[
    Normal Map Inspector add-on script for Aseprite 
    Copyright (C) 2025 ppelikan

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

-- websocket port number
local PORT_NUMBER="44857"
-- script version (for compatibility checking pusposes)
local VER_A=0
local VER_B=5
-- websocket headers
local DIFF_ID = string.byte("D")
local NORM_ID = string.byte("N")
local SPEC_ID = string.byte("S")

local DISABLED_LAYER_LABEL = "- none -"
local SUBLAYER_LAYER_PREFIX = "  "

-- global variables
local finish_fnc
local ws
local config_dialog
local spr
local bufimg
local layer_diff
local layer_norm
local layer_spec
local groups_supported
local tilemap_cache = {}

-- ==========================================================================

-- render a tilemap layer
local function renderTilemap(layer, ce)
    local tile_width = layer.tileset.grid.tileSize.width
    local tile_height = layer.tileset.grid.tileSize.height
    local img_width = ce.image.width * tile_width
    local img_height = ce.image.height * tile_height

    -- create or reuse cached image buffer
    local cache_key = layer.name
    local tilemap_img = tilemap_cache[cache_key]

    if tilemap_img == nil or tilemap_img.width ~= img_width or tilemap_img.height ~= img_height then
        tilemap_img = Image(img_width, img_height)
        tilemap_cache[cache_key] = tilemap_img
    end

    tilemap_img:clear()

    -- render tiles
    for y = 0, ce.image.height - 1 do
        for x = 0, ce.image.width - 1 do
            local tile_index = ce.image:getPixel(x, y)
            if tile_index > 0 then
                local tile_img = layer.tileset:getTile(tile_index)
                if tile_img then
                    tilemap_img:drawImage(tile_img,
                        Point(x * tile_width, y * tile_height))
                end
            end
        end
    end

    return tilemap_img
end

-- send given layer image data with associated id through websocket
local function sendLayer(layer, id)
    if bufimg.width ~= spr.width or bufimg.height ~= spr.height then
        bufimg:resize(spr.width, spr.height)
    end
    bufimg:clear()

    local ce
    local ok = false

    if layer.layers ~= nil then
        -- layer is group of layers
        for _,l in ipairs(layer.layers) do
            ce = l:cel(app.activeFrame.frameNumber)
            if ce ~= nil then
                if l.isTilemap then
                    local tilemap_img = renderTilemap(l, ce)
                    bufimg:drawImage(tilemap_img, ce.position, l.opacity, l.blendMode)
                else
                    bufimg:drawImage(ce.image, ce.position, l.opacity, l.blendMode)
                end
                ok = true
            end
        end
    elseif layer.isTilemap then
        -- layer is a tilemap layer
        ce = layer:cel(app.activeFrame.frameNumber)
        if ce ~= nil then
            local tilemap_img = renderTilemap(layer, ce)
            bufimg:drawImage(tilemap_img, ce.position, layer.opacity, layer.blendMode)
            ok = true
        end
    else
        -- layer is single regular layer
        ce = layer:cel(app.activeFrame.frameNumber)
        if ce ~= nil then
            bufimg:drawImage(ce.image, ce.position)
            ok = true
        end
    end

    if ok == true then
        ws:sendBinary(string.pack("<I4I4I4", id, bufimg.width, bufimg.height))
        -- Aseprite bug forces the user to use the RGB mode
        -- otherwise this function does not work properly!
        ws:sendBinary(bufimg.bytes)
    end
end

-- send the whole sprite frame image data through websocket
local function sendImage()
    if ws == nil then return end
    if layer_diff ~= nil then
        sendLayer(layer_diff, DIFF_ID)
    end
    if layer_norm ~= nil then
        sendLayer(layer_norm, NORM_ID)
    end 
    if layer_spec ~= nil then
        sendLayer(layer_spec, SPEC_ID)
    end
end

-- handle all user interactions with the sprite
local frame = -1
local function onSiteChange()
    if app.activeSprite == spr then
        -- update after changes
        if app.activeFrame.frameNumber ~= frame then
            frame = app.activeFrame.frameNumber
            sendImage()
        end
    else
        -- check if the sprite was closed
        local closed = true
        for _,s in ipairs(app.sprites) do
            if s == spr then 
                closed = false
                -- the sprite is open but in an inactive tab
                break
            end
        end
        -- the sprite was closed
        if closed then
            finish_fnc()
        end
    end
end

-- stop all activity and exit
local function finish()
    if spr ~= nil then spr.events:off(sendImage) end
    app.events:off(onSiteChange)
    if ws ~= nil then ws:close() end
    if config_dialog ~= nil then config_dialog:close() end
    config_dialog = nil
    spr = nil
    ws = nil
    tilemap_cache = {}
end

-- callback for websocket client
local function receive(t, message)
    if ws == nil then return end
    if t == WebSocketMessageType.OPEN then
        -- send introduction
        ws:sendBinary(string.pack("<I4I4I4", string.byte("V"), VER_A, VER_B))
        -- register callbacks for given events
        spr.events:on('change', sendImage)
        app.events:on('sitechange', onSiteChange)
        sendImage()
    elseif t == WebSocketMessageType.CLOSE then
        finish()
    end
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

-- OK button clicked, start connection and data transmission
local function start()
    -- assign selected layers
    layer_diff = get_layer(config_dialog.data.diff_layer)
    layer_norm = get_layer(config_dialog.data.norm_layer)
    layer_spec = get_layer(config_dialog.data.spec_layer)

    ws = WebSocket{ url="ws://127.0.0.1:"..PORT_NUMBER, onreceive=receive, deflate=false, maxreconnectwait=1 }
    ws:connect()

    if config_dialog ~= nil then config_dialog:close() end
    config_dialog = nil
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

if spr.colorMode ~= ColorMode.RGB then
    app.alert{title="Error!", text="Wrong Color Mode detected! Please switch to 'RGB Color' (Sprite -> Color Mode)"}
    return
end

bufimg = Image(spr.width, spr.height, ColorMode.RGB)

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
config_dialog = Dialog{title="NM Inspector"}
if groups_supported == false and found_groups == true then
    config_dialog:label{ label="Warning!", text="Layer groups are unsupported." }
    config_dialog:label{ label="", text="Please update Aseprite" }
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
