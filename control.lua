-- control.lua
-- Concrete Foundations
-- Applies different module bonuses depending on which material fully covers a machine.

local BEACON_NAME = "concrete-beacon"

local BP_TILE_THRESHOLD = 1
local SUPPRESS_TICKS = 5
local DELAY_TICKS = 5


--------------------------------------------------------------------------------
-- Qualified types
--------------------------------------------------------------------------------

local QUALIFYING_TYPES = {
    ["assembling-machine"] = true,
    ["furnace"] = true,
}

local QUALIFYING_TYPE_LIST = {}
local BUILD_FILTERS = {}

for t in pairs(QUALIFYING_TYPES) do
    QUALIFYING_TYPE_LIST[#QUALIFYING_TYPE_LIST + 1] = t
    BUILD_FILTERS[#BUILD_FILTERS + 1] = {
        filter = "type",
        type = t
    }
end


--------------------------------------------------------------------------------
-- Tile -> effect mapping
--------------------------------------------------------------------------------

local CONCRETE_TILES = {
    ["concrete"]                      = "concrete-speed-module",

    ["refined-concrete"]              = "refined-concrete-speed-module",

    ["hazard-concrete-left"]          = "hazard-concrete-prod-module",
    ["hazard-concrete-right"]         = "hazard-concrete-prod-module",

    ["refined-hazard-concrete-left"]  = "refined-hazard-concrete-prod-module",
    ["refined-hazard-concrete-right"] = "refined-hazard-concrete-prod-module",
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

---comment
---@param entity LuaEntity
local function entity_effect_underfoot(entity)
    local tiles = entity.surface.find_tiles_filtered {
        area = entity.bounding_box
    }
    local n = #tiles
    if n == 0 then return nil end


    local buff_effect = CONCRETE_TILES[tiles[1].name]
    if not buff_effect then return nil end
    for i = 2, n do
        if CONCRETE_TILES[tiles[i].name] ~= buff_effect then
            return nil
        end
    end

    return buff_effect
end
---comment
---@param beacon LuaEntity
---@param buff_effet string|nil
local function update_beacon_bonus(beacon, buff_effet)
    if beacon and beacon.valid then
        local inv = beacon.get_module_inventory()
        if inv then
            if buff_effet then
                inv.clear()
                inv.insert { name = buff_effet, count = 1 }
            else
                inv.clear()
            end
        end

        return
    end
end
---comment
---@param surface LuaSurface
---@param tiles LuaTile
local function update_machines_near_tiles(surface, tiles)
    if not (surface and tiles) then return end

    local seen = {}

    for _, t in ipairs(tiles) do
        local p = t.position
        local area = { { p.x, p.y }, { p.x + 1, p.y + 1 } }

        local machines = surface.find_entities_filtered {
            area = area,
            type = QUALIFYING_TYPE_LIST,
        }

        for _, m in ipairs(machines) do
            if m.valid and m.unit_number and not seen[m.unit_number] then
                seen[m.unit_number] = true
                local beacon = storage.entity_personal_beacon[m.unit_number]
                local buff_effect = entity_effect_underfoot(m)
                update_beacon_bonus(beacon, buff_effect)
            end
        end
    end
end



local function get_cursor_blueprint(player)
    local cs = player.cursor_stack
    if not (cs and cs.valid_for_read) then return nil end
    if cs.is_blueprint then return cs end


    if cs.is_blueprint_book then
        local idx = cs.active_index
        if not idx then return nil end

        local inv = cs.get_inventory(defines.inventory.item_main)
        if not inv then return nil end

        local bp = inv[idx]
        if bp and bp.valid_for_read and bp.is_blueprint then
            return bp
        end
    end


    return nil
end

---comment
---@param surface LuaSurface
---@param area table
local function recompute_machines_in_area(surface, area)
    if not surface then return end
    if not area then return end

    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    for _, m in ipairs(machines) do
        local beacon = storage.entity_personal_beacon[m.unit_number]
        local buff_effect = entity_effect_underfoot(m)
        if beacon then
            update_beacon_bonus(beacon, buff_effect)
        end
    end
end

local function build_tile_items_set()
    storage.tile_items = {}

    for _, tile in pairs(prototypes.tile) do
        local items = tile.items_to_place_this
        if items then
            for _, item in pairs(items) do
                storage.tile_items[item.name] = true
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Beacon lifecycle
--------------------------------------------------------------------------------

---comment
---@param entity LuaEntity
local function create_personal_beacon(entity)
    if not (entity and entity.valid and entity.unit_number) then return end

    local beacon = storage.entity_personal_beacon[entity.unit_number]
    if beacon then return beacon end

    -- Create beacon
    local beacon = entity.surface.create_entity {
        name = BEACON_NAME,
        position = entity.position,
        force = entity.force
    }

    storage.entity_personal_beacon[entity.unit_number] = beacon
    return beacon
end

---comment
---@param entity LuaEntity
local function destroy_personal_beacon(entity)
    if not (entity and entity.unit_number) then return end
    local beacon = storage.entity_personal_beacon[entity.unit_number]
    if not beacon then return end
    if beacon.valid then
        beacon.destroy()
    end

    storage.entity_personal_beacon[entity.unit_number] = nil
end

--------------------------------------------------------------------------------
-- Entity Events
--------------------------------------------------------------------------------

local function on_entity_build(event)
    local entity = event.created_entity or event.entity or event.destination
    if not (entity and entity.valid) then return end
    local beacon = create_personal_beacon(entity)
    local buff_effect = entity_effect_underfoot(entity)
    if not beacon then return end
    update_beacon_bonus(beacon, buff_effect)
end

local function on_entity_removed(event)
    local entity = event.created_entity or event.entity or event.destination
    if not (entity) then return end
    destroy_personal_beacon(entity)
end

--------------------------------------------------------------------------------
-- Tile Events
--------------------------------------------------------------------------------

local function on_tiles_changed(event)
    local surface_index = event.surface_index
    local surface = game.surfaces[surface_index]
    if not surface then return end
    local player_index = event.player_index


    local s = storage.last_pre_build[player_index]
    if s and ((game.tick - s.last_tick) < SUPPRESS_TICKS) then
        local suppressed_tiles = storage.suppressed_tiles[player_index]
        local coords = suppressed_tiles[surface_index] or {}

        local minx, miny, maxx, maxy = coords.minx, coords.miny, coords.maxx, coords.maxy
        if not minx then
            local p = s.position
            minx, miny, maxx, maxy = p.x, p.y, p.x, p.y
        end

        local tiles = event.tiles
        for i = 1, #tiles do
            local p = tiles[i].position
            local x, y = p.x, p.y
            if x < minx then minx = x elseif x > maxx then maxx = x end
            if y < miny then miny = y elseif y > maxy then maxy = y end
        end

        suppressed_tiles[surface_index] = coords
        coords.minx, coords.miny, coords.maxx, coords.maxy = minx, miny, maxx, maxy
        return
    end

    update_machines_near_tiles(surface, event.tiles)
end

--------------------------------------------------------------------------------
-- Editor instant_deconstruction
--------------------------------------------------------------------------------

local function custom_handler_editor_instant_deconstruct(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local controller_type = player.controller_type
    if not (controller_type and controller_type == defines.controllers.editor) then return end

    local surface = event.surface
    if not surface then return end

    local area = event.area
    if not area then return end

    recompute_machines_in_area(surface, area)
end

--------------------------------------------------------------------------------
-- Editor instant_blueprint_building
--------------------------------------------------------------------------------
---comment
---@param blueprint LuaItemStack
local function get_tile_count_from_bp(blueprint)
    local total_count = 0

    for _, item in pairs(blueprint.cost_to_build) do
        if storage.tile_items[item.name] then
            total_count = total_count + item.count
        end
    end
    return total_count
end


local function get_tile_count(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local bp = get_cursor_blueprint(player)
    if not bp then
        storage.bp_tilecount[event.player_index] = nil
        return
    end

    local tiles = get_tile_count_from_bp(bp)
    if tiles == 0 then
        tiles = #bp.get_blueprint_tiles()
    end
    storage.bp_tilecount[event.player_index] = tiles or 0
end

local function on_pre_build(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local controller_type = player.controller_type
    if not (controller_type and controller_type == defines.controllers.editor) then return end

    local tile_count = storage.bp_tilecount[event.player_index]
    if tile_count and tile_count >= BP_TILE_THRESHOLD then
        storage.last_pre_build[event.player_index] = {
            last_tick = game.tick,
            position = event.position
        }
    end
    storage.suppressed_tiles[event.player_index] = {}
    storage.run_area_recompute_at[event.player_index] = game.tick + DELAY_TICKS
end

--------------------------------------------------------------------------------
-- Editor on TIck
--------------------------------------------------------------------------------

local function on_tick(event)
    local t = storage.run_area_recompute_at
    if not t then return end

    for player_index, run_tick in pairs(t) do
        if run_tick and event.tick >= run_tick then
            local surfaces = storage.suppressed_tiles and storage.suppressed_tiles[player_index]
            if surfaces then
                for surface_index, coords in pairs(surfaces) do
                    local bb = { { coords.minx, coords.miny }, { coords.maxx, coords.maxy } }
                    local surface = game.surfaces[surface_index]
                    recompute_machines_in_area(surface, bb)
                end
            end

            storage.run_area_recompute_at[player_index] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

local function ensure_storage()
    storage.entity_personal_beacon = storage.entity_personal_beacon or {}
    storage.bp_tilecount = storage.bp_tilecount or {}
    storage.last_pre_build = storage.last_pre_build or {}
    storage.suppressed_tiles = storage.suppressed_tiles or {}
    storage.run_area_recompute_at = storage.run_area_recompute_at or {}
    build_tile_items_set()
end

script.on_init(ensure_storage)

script.on_configuration_changed(ensure_storage)

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

--Tiles
script.on_event(defines.events.on_player_built_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_built_tile, on_tiles_changed)
script.on_event(defines.events.on_player_mined_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_mined_tile, on_tiles_changed)
script.on_event(defines.events.script_raised_set_tiles, on_tiles_changed)

--entity Build
script.on_event(defines.events.on_built_entity, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.on_robot_built_entity, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.script_raised_built, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.script_raised_revive, on_entity_build, BUILD_FILTERS)

--entity Removed
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_entity_died, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, BUILD_FILTERS)

--Instant instant_deconstruction
script.on_event(defines.events.on_player_deconstructed_area, custom_handler_editor_instant_deconstruct)

--Instant instant_blueprint_building
script.on_event(defines.events.on_player_cursor_stack_changed, get_tile_count)
script.on_event(defines.events.on_pre_build, on_pre_build)
script.on_event(defines.events.on_tick, on_tick)


--defines.events.on_undo_applied
