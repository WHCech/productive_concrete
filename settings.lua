-- settings.lua
local has_quality_mod = (mods and (mods["space-age"] or mods["quality"])) and true or false
local buff_types = { "Speed", "Productivity", "Efficiency" }
if has_quality_mod then
    table.insert(buff_types, "Quality")
end

local tiles = {
    { key = "concrete",         label = "Concrete",         default_effect = "Speed",        default_value = 10 },
    { key = "refined_concrete", label = "Refined concrete", default_effect = "Speed",        default_value = 20 },
    { key = "hazard_concrete",  label = "Hazard concrete",  default_effect = "Productivity", default_value = 5 },
    { key = "refined_hazard",   label = "Refined hazard",   default_effect = "Productivity", default_value = 10 },
}

if mods and mods["quality"] and mods["quality_concrete"] then
    data:extend({
        {
            type = "bool-setting",
            name = "productive_concrete_enable_quality_scaling",
            setting_type = "startup",
            default_value = true,
            order = "a"
        }
    })
end
local settings_protos = {}

for i, t in ipairs(tiles) do
    table.insert(settings_protos, {
        type = "string-setting",
        name = "prod_concrete_effect_" .. t.key,
        setting_type = "startup",
        default_value = t.default_effect,
        allowed_values = buff_types,
        order = string.format("a[%02d]-a[%s]", i, t.key),
    })

    table.insert(settings_protos, {
        type = "double-setting",
        name = "prod_concrete_value_" .. t.key,
        setting_type = "startup",
        default_value = t.default_value,
        order = string.format("a[%02d]-b[%s]", i, t.key),
    })
end

data:extend(settings_protos)
