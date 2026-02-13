local qualities = { "normal", "uncommon", "rare", "epic", "legendary" }
local quality_layer_offset = {
    normal = 0,
    uncommon = 1,
    rare = 2,
    epic = 3,
    legendary = 4
}

-- Base item -> which base tile(s) to clone for visuals and placement pattern
local families = {
    {
        base_item = "concrete",
        base_tiles = { "concrete" }
    },
    {
        base_item = "refined-concrete",
        base_tiles = { "refined-concrete" }
    },
    {
        base_item = "hazard-concrete",
        base_tiles = { "hazard-concrete-left", "hazard-concrete-right" }
    },
    {
        base_item = "refined-hazard-concrete",
        base_tiles = { "refined-hazard-concrete-left", "refined-hazard-concrete-right" }
    }
}


-- local function base_place_tile_for_item(item_name)
--     if item_name == "hazard-concrete" or item_name == "refined-hazard-concrete" then
--         return item_name .. "-left"
--     end
--     return item_name
-- end

-- local function make_token(item_name, q)
--     return {
--         type = "item",
--         name = "tile-pickup-token-" .. item_name .. "-" .. q,
--         localised_name = { "", string.upper(string.sub(q, 1, 1)) .. string.sub(q, 2), " ", { "item-name." .. item_name } },
--         icon = data.raw.item[item_name] and data.raw.item[item_name].icon or "__base__/graphics/icons/iron-plate.png",
--         icon_size = 64,
--         stack_size = 100,
--         hidden = false,

--         place_as_tile = {
--             result = base_place_tile_for_item(item_name),
--             condition_size = 1,
--             condition = {
--                 layers = {
--                     ground_tile = true
--                 }
--             },
--         },

--         spoil_ticks = 1, -- spoil almost immediately
--         spoil_to_trigger_result = {
--             items_per_trigger = 1,
--             trigger = {
--                 {
--                     type = "direct",
--                     action_delivery = {
--                         type = "instant",
--                         source_effects = {
--                             {
--                                 type = "insert-item",
--                                 item = item_name,
--                                 quality = q,
--                                 count = 1
--                             }
--                         }
--                     }
--                 }
--             }
--         }
--     }
-- end

-- local function make_quality_tile(base_tile_name, item_name, q)
--     local base = data.raw.tile[base_tile_name]
--     if not base then return nil end

--     local t = table.deepcopy(base)
--     t.name = base_tile_name .. "-quality-" .. q

--     t.minable = t.minable or {}
--     t.minable.result = "tile-pickup-token-" .. item_name .. "-" .. q
--     t.minable.count = 1
--     t.layer = (base.layer or 0) + 100 + (quality_layer_offset[q] or 0)
--     -- t.transition_merges_with_tile = "concrete"
--     t.placeable_by = { item = item_name, count = 1 }

--     return t
-- end

-- local tokens = {}
-- local tiles = {}

-- -- Create tokens and tiles
-- for _, fam in ipairs(families) do
--     local item_name = fam.base_item

--     for _, q in ipairs(qualities) do
--         table.insert(tokens, make_token(item_name, q))

--         for _, base_tile in ipairs(fam.base_tiles) do
--             local qt = make_quality_tile(base_tile, item_name, q)
--             if qt then
--                 table.insert(tiles, qt)
--             end
--         end
--     end
-- end

-- data:extend(tokens)
-- data:extend(tiles)

-- -- Patch hazard next_direction so rotation stays within the same quality tier
-- local function patch_next_direction(left_base, right_base)
--     for _, q in ipairs(qualities) do
--         local left = data.raw.tile[left_base .. "-quality-" .. q]
--         local right = data.raw.tile[right_base .. "-quality-" .. q]
--         if left then left.next_direction = right_base .. "-quality-" .. q end
--         if right then right.next_direction = left_base .. "-quality-" .. q end
--     end
-- end

-- patch_next_direction("hazard-concrete-left", "hazard-concrete-right")
-- patch_next_direction("refined-hazard-concrete-left", "refined-hazard-concrete-right")
