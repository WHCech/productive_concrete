# Productive Concrete

Applies dynamic module bonuses to machines based on the concrete tiles under them.

When used together with [Quality Concrete](https://mods.factorio.com/mod/quality_concrete), module effects can scale with tile quality.

---

## Features

- Automatically creates a hidden beacon for:
  - Assembling machines
  - Furnaces
- Applies different module effects depending on tile type
- Effect and strength can be configured in the mod settings


#### Supported Tiles

| Tile Type | Default Effect |
|------------|---------------|
| `concrete` | Speed module |
| `refined-concrete` | Speed module T2 |
| `hazard-concrete-left/right` | Productivity module |
| `refined-hazard-concrete-left/right` | Productivity module T2 |

A machine must be **fully on the same supported tile** to receive the bonus.

Mixed tiles or unsupported tiles result in no bonus.

---

## How It Works

1. When a qualifying machine is built:
   - A hidden beacon (`concrete-beacon`) is created at the machines position.
2. When tiles under a machine change:
   - The mod checks if the machine is fully on a supported tile.
   - The beacon module is updated accordingly.
3. When a machine is removed:
   - Its corresponding beacon is destroyed.

---

## Performance

This mod does not run continuous scanning logic. Outside of build/mining events, it performs no active work and should have a negligible impact on performance.

