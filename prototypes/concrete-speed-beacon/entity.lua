data:extend({
  {
    type = "beacon",
    name = "concrete-speed-beacon",
    icon = "__base__/graphics/icons/beacon.png",
    icon_size = 64,

    flags = {
      "not-on-map",
      "not-blueprintable",
      "not-deconstructable",
      "placeable-off-grid",
      "not-repairable",
      "no-automated-item-removal",
      "no-automated-item-insertion"
    },
    hidden = true,
    selectable_in_game = false,
    minable = nil,
    max_health = 1,

    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    selection_box = { { 0, 0 }, { 0, 0 } },
    collision_mask = { layers = {} },

    supply_area_distance = 0,
    distribution_effectivity = 1.0,

    energy_source = { type = "void" },
    energy_usage = "1W",

    module_slots = 1,
    allowed_effects = { "speed" },

    radius_visualisation_picture = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    },

    animation = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1,
      frame_count = 1
    },
    base_picture = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    }
  }
})
