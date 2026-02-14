require("prototypes.items")
require("prototypes.concrete-speed-beacon.entity")

local function apply_choice(module_name, effect_setting, value_setting)
    local effect_name = settings.startup[effect_setting].value
    local value = settings.startup[value_setting].value / 100

    local key_map = {
        Speed        = "speed",
        Productivity = "productivity",
        Efficiency   = "consumption",
        Quality      = "quality",
    }

    local key = key_map[effect_name]
    local proto = data.raw.module[module_name]
    if not proto or not key then return end

    proto.effect = proto.effect or {}
    proto.effect.speed = nil
    proto.effect.productivity = nil
    proto.effect.consumption = nil
    proto.effect.quality = nil

    proto.effect[key] = value
end

apply_choice("concrete-module", "prod_concrete_effect_concrete", "prod_concrete_value_concrete")
apply_choice("refined-concrete-module", "prod_concrete_effect_refined_concrete", "prod_concrete_value_refined_concrete")
apply_choice("hazard-concrete-module", "prod_concrete_effect_hazard_concrete", "prod_concrete_value_hazard_concrete")
apply_choice("refined-hazard-concrete-prod-module", "prod_concrete_effect_refined_hazard", "prod_concrete_value_refined_hazard")
