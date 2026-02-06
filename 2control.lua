-- control.lua
-- Concrete Foundations
-- Applies different module bonuses depending on which material fully covers a machine.

local BEACON_NAME = "concrete-speed-beacon"

--------------------------------------------------------------------------------
-- Which entities qualify
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
-- Tile -> effect mapping (YOUR REQUESTED STRUCTURE)
--------------------------------------------------------------------------------

local CONCRETE_TILES = {
    ["concrete"]                      = { module = "concrete-speed-module", count = 1 },

    ["refined-concrete"]              = { module = "refined-concrete-speed-module", count = 1 },

    ["hazard-concrete-left"]          = { module = "hazard-concrete-prod-module", count = 1 },
    ["hazard-concrete-right"]         = { module = "hazard-concrete-prod-module", count = 1 },

    ["refined-hazard-concrete-left"]  = { module = "refined-hazard-concrete-prod-module", count = 1 },
    ["refined-hazard-concrete-right"] = { module = "refined-hazard-concrete-prod-module", count = 1 },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Return effect table {module=..., count=...} if entity is fully on ONE material
-- Return nil if mixed or unsupported
local function entity_effect_underfoot(entity)
    local tiles = entity.surface.find_tiles_filtered {
        area = entity.bounding_box
    }

    local effect = nil

    for i = 1, #tiles do
        local e = CONCRETE_TILES[tiles[i].name]
        if not e then
            return nil
        end

        if not effect then
            effect = e
        else
            if effect.module ~= e.module then
                return nil
            end
        end
    end

    return effect
end


local function find_beacon_at(surface, position)
    local list = surface.find_entities_filtered {
        name = BEACON_NAME,
        position = position
    }

    if list and #list > 0 then
        return list[1]
    end

    return nil
end

--------------------------------------------------------------------------------
-- Bonus management
--------------------------------------------------------------------------------
-- storage.entity_personal_beacon[unit_number] = {
--    beacon = LuaEntity,
--    module = string,
--    count  = number
-- }

local function remove_bonus(entity)
    if not (entity and entity.valid and entity.unit_number) then return end

    local beacon = storage.entity_personal_beacon[entity.unit_number]
    if beacon then
        local inv = beacon.get_module_inventory()
        if inv then
            inv.clear()
        end
    end

    -- storage.entity_personal_beacon[entity.unit_number] = nil
end


local function ensure_bonus(entity, effect)
    if not (entity and entity.valid and entity.unit_number) then return end
    if not effect then return end

    local want_module = effect.module
    local want_count  = effect.count or 1

    local beacon      = storage.entity_personal_beacon[entity.unit_number]

    -- Already exists: update only if different
    if beacon and beacon.valid then
        local inv = beacon.get_module_inventory()
        if inv then
            inv[1].set_stack { name = want_module, count = want_count }
        end

        return
    end

    -- Create beacon
    local beacon = entity.surface.create_entity {
        name = BEACON_NAME,
        position = entity.position,
        force = entity.force
    }

    if not (beacon and beacon.valid) then return end

    local inv = beacon.get_module_inventory()
    if inv then
        inv[1].set_stack { name = want_module, count = want_count }
    end

    storage.entity_personal_beacon[entity.unit_number] = beacon
end


local function update_entity_bonus(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if not QUALIFYING_TYPES[entity.type] then return end

    local effect = entity_effect_underfoot(entity)

    if effect then
        ensure_bonus(entity, effect)
    else
        remove_bonus(entity)
    end
end

--------------------------------------------------------------------------------
-- Tile updates
--------------------------------------------------------------------------------

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
                update_entity_bonus(m)
            end
        end
    end
end


local function on_tiles_changed(event)
    local surface = game.surfaces[event.surface_index]
    if not surface then return end

    update_machines_near_tiles(surface, event.tiles)
end

--------------------------------------------------------------------------------
-- Entity lifecycle
--------------------------------------------------------------------------------

local function on_entity_build(event)
    local entity = event.created_entity or event.entity or event.destination
    if not (entity and entity.valid) then return end

    update_entity_bonus(entity)
end


local function on_entity_removed(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.unit_number) then return end
    if not QUALIFYING_TYPES[entity.type] then return end

    local beacon = find_beacon_at(entity.surface, entity.position)
    if beacon and beacon.valid then
        beacon.destroy()
    end
end

--------------------------------------------------------------------------------
-- Beacon validation (editor / weird states)
--------------------------------------------------------------------------------

local function update_beacon_bonus(beacon)
    if not (beacon and beacon.valid) then return end
    if beacon.name ~= BEACON_NAME then return end

    local surface = beacon.surface
    local p = beacon.position

    local area = { { p.x - 0.49, p.y - 0.49 }, { p.x + 0.49, p.y + 0.49 } }

    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    for _, m in ipairs(machines) do
        if m.valid and m.unit_number then
            update_entity_bonus(m)
            return
        end
    end

    beacon.destroy()
end

--------------------------------------------------------------------------------
-- Full rescan
--------------------------------------------------------------------------------

local function rescan_all()
    storage.entity_personal_beacon = {}

    for _, surface in pairs(game.surfaces) do
        local machines = surface.find_entities_filtered {
            type = QUALIFYING_TYPE_LIST
        }
        local beacons = surface.find_entities_filtered { name = BEACON_NAME }
        for _, b in ipairs(beacons) do
            if b.valid then b.destroy() end
        end

        for _, m in ipairs(machines) do
            if m.valid and m.unit_number then
                local stray = find_beacon_at(surface, m.position)
                if stray and stray.valid then stray.destroy() end
                update_entity_bonus(m)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Editor instant deconstruct
--------------------------------------------------------------------------------

local function custom_handler_editor_instant_deconstruct(event)
    local surface = event.surface
    if not surface then return end

    local area = event.area
    if not area then return end

    local machines = surface.find_entities_filtered {
        area = area,
        type = QUALIFYING_TYPE_LIST
    }

    for _, m in ipairs(machines) do
        update_entity_bonus(m)
    end

    local beacons = surface.find_entities_filtered {
        area = area,
        name = BEACON_NAME
    }

    for _, b in ipairs(beacons) do
        update_beacon_bonus(b)
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

script.on_init(function()
    storage.entity_personal_beacon = storage.entity_personal_beacon or {}
    rescan_all()
end)

script.on_configuration_changed(function()
    storage.entity_personal_beacon = storage.entity_personal_beacon or {}
    rescan_all()
end)

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

script.on_event(defines.events.on_player_built_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_built_tile, on_tiles_changed)
script.on_event(defines.events.on_player_mined_tile, on_tiles_changed)
script.on_event(defines.events.on_robot_mined_tile, on_tiles_changed)
script.on_event(defines.events.script_raised_set_tiles, on_tiles_changed)

script.on_event(defines.events.on_built_entity, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.on_robot_built_entity, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.script_raised_built, on_entity_build, BUILD_FILTERS)
script.on_event(defines.events.script_raised_revive, on_entity_build, BUILD_FILTERS)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.on_entity_died, on_entity_removed, BUILD_FILTERS)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, BUILD_FILTERS)

script.on_event(defines.events.on_player_deconstructed_area, custom_handler_editor_instant_deconstruct)
--defines.events.on_undo_applied
