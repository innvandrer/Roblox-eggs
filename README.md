# Monster Egg Grinder

A Roblox game built with Rojo. Kill monsters for coins, XP and eggs, buy better gear, plant eggs on your
base plot, hatch them into pets and evolve the pets to get stronger.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then from the repo root run:

   ```sh
   rokit install      # rojo, selene, stylua, wally, lune, luau-lsp (versions in rokit.toml)
   wally install      # Comm (networking) and ProfileStore (saving)
   ```

2. Install the Rojo plugin in Roblox Studio (`rojo plugin install`, or from the Creator Store).

## Play

1. Run `rojo serve`.
2. Open a new Baseplate in Studio, open the Rojo plugin and click **Connect**.
3. Press **Play**.

Alternatively, run `rojo build -o build/Roblox-eggs.rbxlx` (or download the `Roblox-eggs-place` artifact from
CI) and open the file in Studio.

Saving uses ProfileStore. In an unpublished place, or without **Game Settings > Security > Enable Studio
Access to API Services**, ProfileStore runs in mock mode: everything works, but data resets when you stop.

### How to play

- Walk east from spawn to **Slime Meadow** and click to swing your sword at monsters.
- Kills give coins and XP. Some kills drop eggs (Common, Rare, Epic or Legendary).
- **Shop** (B, or the stand at spawn): buy weapons and armor. Items have level requirements.
- **Plot** (G, or walk west to your plot): plant eggs. They grow on a real-time timer, including while you're
  offline. Hatch them when they're ready. Buy more slots with coins.
- **Pets** (P): equip up to 3 pets for damage or coin boosts. Evolve a pet by merging 3 of the same pet at the
  same stage, or by feeding it coins.
- **Haunted Graveyard** unlocks at level 5.

## Project layout

| Path | Contents |
| --- | --- |
| `src/shared/Config` | All game data: weapons, armor, monsters, zones, eggs, pets, leveling, plot prices |
| `src/shared/Logic` | Pure gameplay rules (leveling, shop, plots, pets, rewards) shared by server and client |
| `src/server` | Services: data, map, monsters, combat, shop, plots, pets, zone guard |
| `src/client` | HUD, menus, notifications, effects |
| `tests` | Lune tests for the shared logic and the built place |

Balancing means editing tables in `src/shared/Config`, not code.

## Checks

```sh
stylua --check src tests
selene src && (cd tests && selene .)
lune run tests/run.luau
rojo build -o build/Roblox-eggs.rbxlx && lune run tests/place.luau
```

CI runs all of these, type-checks `src` with `luau-lsp`, and uploads the built place file.
