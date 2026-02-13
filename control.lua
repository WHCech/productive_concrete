-- control.lua
-- Concrete Foundations
-- Applies different module bonuses depending on which material fully covers a machine.

local BEACON_NAME = "concrete-beacon"

local BP_TILE_THRESHOLD = 3000
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

local CONCRETE_TILES = {}

if script.active_mods["quality_concrete"] and settings.startup["productive_concrete_enable_quality_scaling"] and settings.startup["productive_concrete_enable_quality_scaling"].value then
    local MODULE_FOR_BASE = {
        ["concrete"]         = "concrete-module",
        ["refined-concrete"] = "refined-concrete-module",
    }

    local function parse_quality_tile(name, base)
        local prefix = base .. "-quality-"
        if name:sub(1, #prefix) ~= prefix then return nil end
        -- everything after "<base>-quality-" is the quality name
        return name:sub(#prefix + 1)
    end

    for tile_name, _ in pairs(prototypes.tile) do
        local q

        q = parse_quality_tile(tile_name, "concrete")
        if q then
            CONCRETE_TILES[tile_name] = { module = MODULE_FOR_BASE["concrete"], quality = q, family = "concrete" }
        else
            q = parse_quality_tile(tile_name, "refined-concrete")
            if q then
                CONCRETE_TILES[tile_name] = {
                    module = MODULE_FOR_BASE["refined-concrete"],
                    quality = q,
                    family =
                    "refined-concrete"
                }
            else
                q = parse_quality_tile(tile_name, "hazard-concrete-left") or
                    parse_quality_tile(tile_name, "hazard-concrete-right")
                if q then
                    CONCRETE_TILES[tile_name] = {
                        module = "hazard-concrete-module",
                        quality = q,
                        family =
                        "hazard-concrete"
                    }
                else
                    q = parse_quality_tile(tile_name, "refined-hazard-concrete-left") or
                        parse_quality_tile(tile_name, "refined-hazard-concrete-right")
                    if q then
                        CONCRETE_TILES[tile_name] = {
                            module = "refined-hazard-concrete-module",
                            quality = q,
                            family =
                            "refined-hazard-concrete"
                        }
                    end
                end
            end
        end
    end
else
    CONCRETE_TILES = {
        ["concrete"]                      = "concrete-module",

        ["refined-concrete"]              = "refined-concrete-module",

        ["hazard-concrete-left"]          = "hazard-concrete-module",
        ["hazard-concrete-right"]         = "hazard-concrete-module",

        ["refined-hazard-concrete-left"]  = "refined-hazard-concrete-module",
        ["refined-hazard-concrete-right"] = "refined-hazard-concrete-module",
    }
end



local TILE_ITEMS = {}
--------------------------------------------------------------------------------
-- Helpers
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
    if beacon and beacon.valid then
        beacon.destroy()
        storage.entity_personal_beacon[entity.unit_number] = nil
        return
    end

    local surface = entity.surface
    local pos = entity.position

    local found = surface.find_entities_filtered {
        position = pos,
        name = BEACON_NAME
    }
    local count = 0
    for i = 1, #found do
        local b = found[i]
        if b.valid then
            b.destroy()
            count = count + 1
        end
    end

    if count > 1 then
        log(string.format(
            "[Productive Concrete] Multiple stray beacons (%d) at (%.1f, %.1f) on surface %s for unit %d",
            count,
            pos.x, pos.y,
            surface.name,
            entity.unit_number
        ))
    end
    storage.entity_personal_beacon[entity.unit_number] = nil
end

---comment
---@param entity LuaEntity
local function entity_effect_underfoot(entity)
    local tiles = entity.surface.find_tiles_filtered { area = entity.bounding_box }
    local n = #tiles
    if n == 0 then
        return nil, nil
    end

    local function unpack_effect(v)
        if not v then return nil, nil end
        if type(v) == "table" then
            return v.module, v.quality
        end
        -- string mapping (no quality info)
        return v, nil
    end

    local first = tiles[1]
    local first_val = CONCRETE_TILES[first.name]
    local first_module, first_quality = unpack_effect(first_val)
    if not first_module then
        return nil, nil
    end

    for i = 2, n do
        local v = CONCRETE_TILES[tiles[i].name]
        local m, q = unpack_effect(v)

        -- must be fully covered by the same material AND same quality
        if m ~= first_module or q ~= first_quality then
            return nil, nil
        end
    end

    return first_module, first_quality
end

---comment
---@param beacon LuaEntity
---@param buff_effect string|nil
local function update_beacon_bonus(beacon, buff_effect, quality)
    local inv = beacon.get_module_inventory()

    if buff_effect then
        inv[1].set_stack { name = buff_effect, count = 1, quality = quality }
    else
        inv.clear()
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
                local buff_effect, quality = entity_effect_underfoot(m)
                update_beacon_bonus(beacon, buff_effect, quality)
            end
        end
    end
end

---comment
---@param surface LuaSurface
---@param area table
local function recompute_machines_in_area(surface, area)
    if not (surface and area) then return end

    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    for _, m in ipairs(machines) do
        local buff_effect, quality = entity_effect_underfoot(m)
        local beacon = storage.entity_personal_beacon[m.unit_number]
        if not (beacon and beacon.valid) then
            beacon = create_personal_beacon(m)

            storage.entity_personal_beacon[m.unit_number] = beacon
        end
        update_beacon_bonus(beacon, buff_effect, quality)
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

local function build_tile_items_set()
    local tile_items = {}

    for _, tile in pairs(prototypes.tile) do
        local items = tile.items_to_place_this
        if items then
            for _, item in pairs(items) do
                tile_items[item.name] = true
            end
        end
    end
    return tile_items
end

---comment
---@param blueprint LuaItemStack
local function get_tile_count_from_bp(blueprint)
    local total_count = 0

    for _, item in pairs(blueprint.cost_to_build) do
        if TILE_ITEMS[item.name] then
            total_count = total_count + item.count
        end
    end
    return total_count
end

--------------------------------------------------------------------------------
-- Entity Events
--------------------------------------------------------------------------------

local function on_entity_build(event)
    local entity = event.created_entity or event.entity or event.destination
    if not (entity and entity.valid) then return end
    local beacon = create_personal_beacon(entity)

    local buff_effect, quality = entity_effect_underfoot(entity)
    update_beacon_bonus(beacon, buff_effect, quality)
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

    local surface = game.surfaces[surface_index]
    if not surface then return end
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
        tiles = #(bp.get_blueprint_tiles() or {})
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
-- Editor Undo
--------------------------------------------------------------------------------

local function on_undo(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local controller_type = player.controller_type
    if not (controller_type and controller_type == defines.controllers.editor) then return end

    local minx, miny, maxx, maxy
    local surface_index

    for _, a in ipairs(event.actions) do
        if a.type == "built-tile" then
            surface_index = surface_index or a.surface_index

            assert(
                surface_index == a.surface_index,
                "Undo affected multiple surfaces\n" .. surface_index .. " : " .. a.surface_index
            )

            local p = a.position
            local x, y = p.x, p.y

            if not minx then
                minx, miny, maxx, maxy = x, y, x, y
            else
                if x < minx then minx = x elseif x > maxx then maxx = x end
                if y < miny then miny = y elseif y > maxy then maxy = y end
            end
        end
    end

    if not minx then return end

    local surface = game.surfaces[surface_index]
    if not surface then return end

    local area = { { minx, miny }, { maxx + 1, maxy + 1 } }
    recompute_machines_in_area(surface, area)
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
                    local bb = { { coords.minx, coords.miny }, { coords.maxx + 1, coords.maxy + 1 } }
                    local surface = game.surfaces[surface_index]
                    recompute_machines_in_area(surface, bb)
                end
            end

            storage.run_area_recompute_at[player_index] = nil
            storage.suppressed_tiles[player_index] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Migration
--------------------------------------------------------------------------------

local function rescan_all()
    for _, surface in pairs(game.surfaces) do
        -- Find all qualifying machines on this surface
        local machines = surface.find_entities_filtered{
            type = QUALIFYING_TYPE_LIST
        }

        for _, m in ipairs(machines) do
            if m.valid and m.unit_number then
                local buff_effect, quality = entity_effect_underfoot(m)

                local beacon = storage.entity_personal_beacon[m.unit_number]
                if not (beacon and beacon.valid) then
                    beacon = create_personal_beacon(m)
                    storage.entity_personal_beacon[m.unit_number] = beacon
                end

                update_beacon_bonus(beacon, buff_effect, quality)
            end
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
end

local function rebuild_runtime()
    TILE_ITEMS = build_tile_items_set()
end

script.on_init(function()
    ensure_storage()
    rebuild_runtime()
end)

script.on_configuration_changed(function()
    ensure_storage()
    rebuild_runtime()
    rescan_all()
end)

script.on_load(function()
    rebuild_runtime()
end)

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

--Editor Undo
script.on_event(defines.events.on_undo_applied, on_undo)