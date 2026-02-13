-- prototypes/items.lua

local enable_quality = (mods and (mods["space-age"] or mods["quality"])) and true or false

local MODULES = {
    { key = "concrete",         name = "concrete-module",                tier = 1 },
    { key = "refined_concrete", name = "refined-concrete-module",        tier = 2 },
    { key = "hazard_concrete",  name = "hazard-concrete-module",         tier = 1 },
    { key = "refined_hazard",   name = "refined-hazard-concrete-module", tier = 2 },
}

local ICON_FOR_CHOICE = {
    Speed        = "__base__/graphics/icons/speed-module.png",
    Productivity = "__base__/graphics/icons/productivity-module.png",
    Efficiency   = "__base__/graphics/icons/efficiency-module.png",
    Quality      = "__quality__/graphics/icons/quality-module.png",
}

local KEY_FOR_CHOICE = {
    Speed        = "speed",
    Productivity = "productivity",
    Efficiency   = "efficiency",
    Quality      = "quality",
}

local function get_startup(name, fallback)
    local s = settings.startup[name]
    if not s then return fallback end
    return s.value
end

local function effect_and_category_for(tile_key)
    local chosen = get_startup("prod_concrete_effect_" .. tile_key, "Speed")
    local value_pct = tonumber(get_startup("prod_concrete_value_" .. tile_key, 0)) or 0

    -- If quality isn't available, force a valid non-quality choice.
    if chosen == "Quality" and not enable_quality then
        chosen = "Speed"
    end

    local key = KEY_FOR_CHOICE[chosen] or "speed"

    local value = value_pct / 100

    local effect = {}
    effect[key] = value

    return effect, key, chosen
end

local protos = {}

for _, m in ipairs(MODULES) do
    local effect, category, chosen = effect_and_category_for(m.key)

    local icon = ICON_FOR_CHOICE[chosen] or "__base__/graphics/icons/speed-module.png"
    local icon_size = 64

    -- If the chosen icon is from __quality__ but the mod isn't present, fall back.
    if chosen == "Quality" and not (mods and mods["quality"]) then
        icon = "__base__/graphics/icons/speed-module.png"
    end

    protos[#protos + 1] = {
        type = "module",
        name = m.name,
        icon = icon,
        icon_size = icon_size,
        hidden = true,
        subgroup = "module",
        category = category,
        tier = m.tier,
        stack_size = 1,
        effect = effect,
        quality = enable_quality and { affects = true } or nil,
    }
end

data:extend(protos)
