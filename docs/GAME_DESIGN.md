# Claim Earth - Current Game Design

## Product

**Claim Earth** is a small cartoon arcade game made for the "Center of Earth" jam
theme. The player descends through a generated hex cave with bombs and a grappling
hook, then must plant the flag to bank the run's depth.

The current game is a portfolio base for further iteration. Preserve its central
risk decision: going deeper improves the possible score, but dying before planting
the flag loses it.

## Core Loop

1. The menu shows a generated cave preview and the current leaderboard owner.
2. Starting creates a randomized deterministic map and a fresh inventory.
3. The player descends by walking, jumping, grappling, and digging with bombs.
4. The player throws the flag when ready to claim a depth.
5. A valid landing opens editable name entry and saves/submits the score.
6. Death or a flag destroyed by lava ends the run without saving its depth.
7. The player restarts with a new seed or returns to the menu.

## Controls

| Input | Action |
| --- | --- |
| `A`, `D` | Walk, air control, or add swing momentum |
| `Space` | Jump, including configured coyote time and jump buffering |
| `W`, `S` | Shorten or lengthen the rope while attached |
| Left mouse | Throw the selected item toward the cursor |
| Right mouse hold | Launch and hold the grappling hook |
| Right mouse release | Detach the hook |
| `1`, `2`, `3` | Select small bomb, large bomb, or flag |
| `Escape` | Pause or leave the current modal |

The in-game HUD presents inventory as a compact bottom icon toolbar with the selected
item highlighted. Toolbar items can be clicked to select them. Changing selection
briefly shows the item name above the toolbar.
A compact pause button opens the pause menu, which contains Resume and Back to Menu
actions.

The first second of a run blocks throws so the Start click cannot fire an item.

## World

- The default map is 100 columns by 2000 rows of flat-top hexes.
- The final two rows are stone. Horizontal escape is prevented by invisible player
  bounds rather than visible stone columns.
- The camera is horizontally locked to the map and only follows downward.
- Initial terrain is deterministic for a given seed.
- Generation uses an ordered resource-driven pass stack. The shipped default stack
  layers base cave noise, typed hazard pocket instances for sand/water/lava, spawn
  carving, and bottom sealing.
- The generation profile and pass tuning live in
  `config/generation/default_profile.tres`.

### Terrain Rules

| Terrain | Collision | Motion/hazard | Bomb response |
| --- | --- | --- | --- |
| Air | Passable | Stable | None |
| Stone | Solid | Stable | Becomes dirt |
| Dirt | Solid | Stable | Becomes sand |
| Sand | Solid at half fill or more | Falls, can creep side-down, displaces passable moving terrain below, never rises; burial hazard only when full | Becomes air |
| Water | Passable | Falls and flows quickly side-down and side-up by CA fill offset; suffocation hazard only when full | Diffuses propagation |
| Lava | Passable | Falls and flows like a slow viscous liquid; side-up overflow is slow and ignores small fill differences; lethal at 10% fill or more | Detonates bombs |

Moving terrain cells store a 0-255 fill amount. A cell keeps one terrain type, but
partial fill controls movement and rendering. Moving terrain tries to fall first,
then flow side-down, then side-up when its motion resource allows it. Side flow
uses a cellular automata fill offset: side-down flow stops before crossing
`source_fill == target_fill - side_flow_offset`, and side-up flow stops before
crossing `source_fill == target_fill + side_flow_offset`. Liquids use a
geometry-matched offset so settled pools render with a flat surface across
staggered hex columns. If both side targets can receive fluid in a tick, the
transfer splits evenly. Water uses fast side-flow rates; lava uses the same rule
with slower rates and a minimum fill difference. Water/lava contact creates
stone whenever both have nonzero fill. Settled liquids do not oscillate
indefinitely.
Terrain simulation targets a commit every 0.1 seconds; simulation and presentation
work are spread across frames so player physics, projectiles, and input remain
responsive.

## Player And Camera

- The player is about two hexes tall and can step up low hex slopes.
- Movement includes ground acceleration, air control, coyote time, jump buffering,
  and floor support probing.
- The hook attaches only to hookable terrain within its configured range.
- `A/D` adds tangential momentum while hooked; `W/S` adjusts rope length.
- The camera remains horizontally fixed and zooms so the map width fills the
  viewport. It never scrolls upward during a run.

The player dies from lava at 10% fill or more, prolonged full-water exposure, full
sand burial, a bomb's lethal radius, or falling below the world. Death never records
current depth.

## Items

Every run starts with 10 small bombs, 2 large bombs, and 1 flag. Item tuning lives
under `config/items/`.

### Bombs

- Bombs follow projectile gravity and bounce until their fuse expires.
- Small bombs are tuned for a longer throw than large bombs.
- Terrain inside the lethal radius is vaporized to air regardless of type.
- Outside the lethal radius, terrain uses its configured blast reaction.
- Lava detonates a bomb immediately; water reduces blast propagation.
- The player dies when inside the lethal radius.

### Flag

- The flag is thrown using projectile physics and does not bounce.
- It ignores water, is destroyed by lava at 10% fill or more, and sticks on its first valid solid
  landing.
- Throwing it locks further item throws until it resolves.
- Landing depth, not current player depth, is the score.

## Scores And Leaderboard

- Greater integer depth is better.
- Local storage keeps the last player name, personal best, and pending submissions.
- Name entry is prefilled on later runs but remains editable.
- Personal and global best depths appear as non-colliding world markers.
- SimpleBoards provides the global leaderboard and menu owner text.
- Network failure never removes a valid local personal best.
- Automated tests always inject `FakeLeaderboardService` and make no real requests.

## Presentation

- Current art is original SVG or procedural drawing; terrain is procedurally styled.
- Water, lava, sand, stone, and dirt must remain distinguishable by pattern and shape,
  not color alone. Partial moving cells show their fill level; if a partial moving
  cell has liquid above, the empty portion draws that liquid, and if it has solid
  above, it renders as a full hex of its own material.
- `AudioDirector`, `GameplayFeedback`, and camera shake are presentation only and must
  not own gameplay decisions.
- Desktop keyboard and mouse are the supported input scheme. Mobile and touch are not
  current targets.

## Feature Invariants

New features may change balance and presentation, but should preserve these unless
this document is deliberately revised:

- Only a valid planted flag creates a score.
- The same seed creates the same initial map.
- Terrain and item behavior remains resource-driven and type-agnostic at call sites.
- No per-cell scene nodes are introduced.
- Simulation work does not stall frame-by-frame input and physics.
- Web remains a supported release target.
