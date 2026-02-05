-- control.lua
-- Concrete Foundations: +10% speed if machine is fully on concrete

local BEACON_NAME = "concrete-speed-beacon"
local MODULE_NAME = "concrete-speed-module"

-- Which entities should qualify?
local QUALIFYING_TYPES = {
    ["assembling-machine"] = true,
    ["furnace"] = true,
}

local QUALIFYING_TYPE_LIST = {}
for t in pairs(QUALIFYING_TYPES) do
    QUALIFYING_TYPE_LIST[#QUALIFYING_TYPE_LIST + 1] = t
end

--Filter events
local BUILD_FILTERS = {
    { filter = "type", type = "assembling-machine" },
    { filter = "type", type = "furnace" },
}

-- Tiles that count as "concrete"
local CONCRETE_TILES = {
    ["concrete"] = true,
    ["refined-concrete"] = true,
    ["hazard-concrete-left"] = true,
    ["hazard-concrete-right"] = true,
    ["refined-hazard-concrete-left"] = true,
    ["refined-hazard-concrete-right"] = true,
}

-- local function ensure_storage()
--     storage.concrete_bonus = storage.concrete_bonus or {} -- [machine_unit_number] = true
-- end

local function is_concrete(tile_name)
    return CONCRETE_TILES[tile_name] == true
end

-- Iterate the tiles under an entity and check they are all concrete.
-- Uses the entity's bounding_box projected onto the tile grid.
local function entity_fully_on_concrete(entity)
    local surface = entity.surface
    local bb      = entity.bounding_box

    -- Convert entity AABB into integer tile coords.
    -- Tiles are 1x1 squares at integer coordinates.
    local left    = math.floor(bb.left_top.x)
    local top     = math.floor(bb.left_top.y)
    local right   = math.ceil(bb.right_bottom.x) - 1
    local bottom  = math.ceil(bb.right_bottom.y) - 1

    for x = left, right do
        for y = top, bottom do
            local tile = surface.get_tile(x, y)
            if not (tile and is_concrete(tile.name)) then
                return false
            end
        end
    end

    return true
end

local function find_beacon_at(surface, position)
    -- Because we place beacon at exactly entity.position, this is reliable.
    -- Some entities use half-tile positions; position filter handles that.
    local list = surface.find_entities_filtered { name = BEACON_NAME, position = position }
    if list and #list > 0 then
        return list[1]
    end
    return nil
end

-- local function add_bonus(entity)
--     if not (entity and entity.valid and entity.unit_number) then return end
--     if storage.concrete_bonus[entity.unit_number] then return end

--     -- Create hidden beacon under machine
--     local beacon = entity.surface.create_entity {
--         name = BEACON_NAME,
--         position = entity.position,
--         force = entity.force,
--     }
--     if not (beacon and beacon.valid) then return end

--     -- Insert hidden module
--     local inv = beacon.get_module_inventory()
--     if inv then
--         inv.insert { name = MODULE_NAME, count = 1 }
--     end

--     storage.concrete_bonus[entity.unit_number] = true
-- end

local function add_bonus(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    local b = storage.concrete_bonus[entity.unit_number]
    if b and b.valid then return end

    local beacon = entity.surface.create_entity{ name=BEACON_NAME, position=entity.position, force=entity.force }
    if not (beacon and beacon.valid) then return end
    local inv = beacon.get_module_inventory()
    if inv then inv.insert{ name=MODULE_NAME, count=1 } end

    storage.concrete_bonus[entity.unit_number] = beacon
end

-- local function remove_bonus(entity)
--     if not (entity and entity.valid and entity.unit_number) then return end
--     if not storage.concrete_bonus[entity.unit_number] then return end

--     -- Destroy hidden beacon at machine position (cleanup)
--     local beacon = find_beacon_at(entity.surface, entity.position)
--     if beacon and beacon.valid then
--         beacon.destroy()
--     end

--     storage.concrete_bonus[entity.unit_number] = nil
-- end

local function remove_bonus(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    local beacon = storage.concrete_bonus[entity.unit_number]
    if beacon and beacon.valid then beacon.destroy() end
    storage.concrete_bonus[entity.unit_number] = nil
end

local function update_entity_bonus(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if not QUALIFYING_TYPES[entity.type] then return end

    if entity_fully_on_concrete(entity) then
        add_bonus(entity)
    else
        remove_bonus(entity)
    end
end

local function update_beacon_bonus(beacon)
    if not (beacon and beacon.valid) then return end
    if beacon.name ~= BEACON_NAME then return end

    local surface = beacon.surface
    local p = beacon.position

    -- Small area around beacon tile to find overlapping machines
    local area = { { p.x - 0.49, p.y - 0.49 }, { p.x + 0.49, p.y + 0.49 } }

    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    local machine = nil
    for _, m in ipairs(machines) do
        if m.valid and m.unit_number and QUALIFYING_TYPES[m.type] then
            machine = m
            break
        end
    end

    -- No machine → orphan beacon
    if not machine then
        beacon.destroy()
        return
    end

    -- Machine exists but no longer fully on concrete → remove
    if not entity_fully_on_concrete(machine) then
        beacon.destroy()
        return
    end

    -- Otherwise still valid → keep
end

-- Given a list of tile positions, find machines that overlap those tiles and update them.
local function update_machines_near_tiles(surface, tiles)
    if not (surface and tiles) then return end

    local seen = {} -- de-dup by unit_number

    for _, t in ipairs(tiles) do
        -- Each tile is at t.position = {x=..., y=...}
        local p = t.position
        local area = { { p.x, p.y }, { p.x + 1, p.y + 1 } }

        local machines = surface.find_entities_filtered {
            area = area,
            type = QUALIFYING_TYPE_LIST,
        }

        for _, m in ipairs(machines) do
            if m.valid and m.unit_number and not seen[m.unit_number] then
                seen[m.unit_number] = true
                update_entity_bonus(m)
            end
        end
    end
end

-- Tile placement/removal events
local function on_tiles_changed(event)
    local surface = game.surfaces[event.surface_index]
    if not surface then return end

    -- event.tiles: list of {old_tile, position} for build events and mine events (varies by event)
    -- In Factorio 2.0 these events always include positions; good enough for proximity search.
    update_machines_near_tiles(surface, event.tiles)
end

-- Entity built / rotated / cloned: evaluate footprint.
local function on_entity_changed(event)
    local entity = event.created_entity or event.entity or event.destination
    if not (entity and entity.valid) then return end
    update_entity_bonus(entity)
end

-- Entity removed: cleanup beacon even if our global tracking missed it.
local function on_entity_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if not entity.unit_number then return end
    if not QUALIFYING_TYPES[entity.type] then return end

    -- Remove bonus and beacon
    remove_bonus(entity)

    -- Extra safety: if a beacon exists at that position (somehow), destroy it
    local beacon = find_beacon_at(entity.surface, entity.position)
    if beacon and beacon.valid then
        beacon.destroy()
    end
end

-- Rebuild/repair global after mod changes (and validate existing beacons)
local function rescan_all()
    storage.concrete_bonus = {}
    for _, surface in pairs(game.surfaces) do
        local machines = surface.find_entities_filtered { type = QUALIFYING_TYPE_LIST }
        for _, m in ipairs(machines) do
            if m.valid and m.unit_number and QUALIFYING_TYPES[m.type] then
                -- Remove any stray beacon first (optional cleanup)
                local beacon = find_beacon_at(surface, m.position)
                if beacon and beacon.valid then beacon.destroy() end
                update_entity_bonus(m)
            end
        end
    end
end

local function custom_handler_editor_instant_deconstruct(event)
    local player = game.get_player(event.player_index)
    if not (player and player.controller_type == defines.controllers.editor) then return end

    local surface = event.surface
    if not surface then return end

    local area = event.area
    if not area then return end


    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    local seen = {}
    for _, m in ipairs(machines) do
        if m.valid and m.unit_number and QUALIFYING_TYPES[m.type] and not seen[m.unit_number] then
            seen[m.unit_number] = true
            update_entity_bonus(m)
        end
    end

    local beacons = surface.find_entities_filtered {
        area = area,
        name = BEACON_NAME
    }

    for _, b in ipairs(beacons) do
        update_beacon_bonus(b)
    end
end

script.on_init(function()
    storage.concrete_bonus = storage.concrete_bonus or {}
    rescan_all()
end)

script.on_configuration_changed(function()
    storage.concrete_bonus = storage.concrete_bonus or {}
    rescan_all()
end)



-- Tiles placed/removed
script.on_event(defines.events.on_player_built_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_built_tile, on_tiles_changed)
script.on_event(defines.events.on_player_mined_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_mined_tile, on_tiles_changed)
script.on_event(defines.events.script_raised_set_tiles, on_tiles_changed)

-- Machines built / rotated
script.on_event(defines.events.on_built_entity, on_entity_changed, BUILD_FILTERS)
script.on_event(defines.events.on_robot_built_entity, on_entity_changed, BUILD_FILTERS)
script.on_event(defines.events.on_player_rotated_entity, on_entity_changed)
script.on_event(defines.events.on_player_flipped_entity, on_entity_changed)
script.on_event(defines.events.script_raised_built, on_entity_changed, BUILD_FILTERS)
script.on_event(defines.events.script_raised_revive, on_entity_changed, BUILD_FILTERS)

-- Machines removed
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_entity_died, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, BUILD_FILTERS)

-- Custom handler for instant deconstruction in editor
script.on_event(defines.events.on_player_deconstructed_area, custom_handler_editor_instant_deconstruct)
