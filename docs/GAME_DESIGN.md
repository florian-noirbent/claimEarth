# Claim Earth - Current Game Design

## Product

**Claim Earth** is a small cartoon arcade game made for the "Center of Earth" jam
theme. The player descends through a generated hex cave with bombs and a grappling
hook, then must plant the flag to bank the run's depth.

The current game is a portfolio base for further iteration. Preserve its central
risk decision: going deeper improves the possible score, but dying before planting
the flag loses it.

## Core Loop

1. The menu shows illustrated cave background art, a top-centered title, stylized
   action buttons, a corner leaderboard owner, and Help and Settings pages for
   rules, controls, and device preferences.
2. Starting creates a randomized deterministic map and a fresh inventory.
3. The player descends by walking, jumping, grappling, and digging with bombs.
4. The player throws the flag when ready to claim a depth.
5. A valid landing opens editable name entry and saves/submits the score.
6. Death or a flag destroyed by lava ends the run without saving its depth.
7. The player restarts with a new seed or returns to the menu.

## Controls

Keyboard and mouse remain fully supported on desktop.

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

### Phone Controls

Phone controls are shown during a playable run when enabled. They default on when
the build reports Godot's `mobile`, `web_android`, or `web_ios` feature; this covers
native mobile exports as well as mobile Web builds. The main-menu Settings screen
contains a Phone Controls toggle. A user change is saved as an explicit preference
and takes precedence over automatic detection, so the controls can also be enabled
for desktop testing.

The touch overlay is designed for landscape fullscreen play:

| Control | Action |
| --- | --- |
| Left stick | Move horizontally; when free, push up to jump; while hooked, push up/down to shorten/lengthen the rope |
| Right stick | Drag to aim; release outside its activation threshold to throw or use the selected item |
| Right ring | Press in a direction to launch the hook, hold to remain attached, and release to detach |

The inventory toolbar remains touchable for item selection. Touch controls are hidden
outside an active run and do not duplicate their gestures as mouse item throws.
Web builds provide a persistent top-right fullscreen toggle. Browsers still require
the player to press the button before fullscreen can be entered.

### Standard Gamepad

| Input | Action |
| --- | --- |
| Left stick or D-pad | Move horizontally; while hooked, adjust rope length |
| A / Cross | Jump |
| Right stick | Aim, retaining the last non-zero direction while centered |
| RT / R2 | Throw or use the selected item |
| LT / L2 | Press, hold, and release the hook |
| LB / RB | Cycle inventory backward/forward |
| Start / Menu | Pause |
| B / Circle | Back or cancel |

The in-game HUD presents inventory as a compact bottom icon toolbar with the selected
item highlighted. Toolbar items can be clicked to select them. Changing selection
briefly shows the item name above the toolbar.
A live integer FPS reading appears with the top-left run status during active play in
all release and debug builds so device performance can be compared directly.
A compact pause button opens the pause menu, which contains Resume and Back to Menu
actions.

Active hazards appear as an icon-only stack of filling bars at the top center. Building
bars pulse with a gold warning outline; recovering bars are dimmed with a downward
indicator. The stack is generic so future terrain hazards can add their own icon and
color without HUD-specific logic.

The first second of a run blocks throws so the Start click cannot fire an item.

## World

- The default map is 100 columns by 512 rows of flat-top hexes.
- The final two rows are stone. Horizontal escape is prevented by invisible player
  bounds rather than visible stone columns.
- The camera is horizontally locked to the map and only follows downward.
- Initial terrain is deterministic for a given seed.
- Generation uses an ordered resource-driven pass stack. The shipped default stack
  layers base cave noise, typed hazard pocket instances for sand/water/lava, a
  noisy surface spawn shaft, and bottom sealing.
- The player starts at surface depth 0 in a roughly six-cell-wide zig-zag shaft
  with noisy edges and occasional broken segments that winds down to the configured
  shaft target depth.
- The generation profile and pass tuning live in
  `config/generation/default_profile.tres`.

### Terrain Rules

| Terrain | Collision | Motion/hazard | Bomb response |
| --- | --- | --- | --- |
| Air | Passable | Stable | None |
| Stone | Solid | Stable | Becomes dirt |
| Dirt | Solid | Stable | Becomes sand |
| Sand | Solid at half fill or more | Falls, can creep side-down, pushes passable moving terrain below side-down before swapping any remainder upward, never rises; pushes the player out rather than burying them | Becomes air |
| Water | Passable | Falls and flows quickly side-down and side-up by CA fill offset; contributes no terrain-specific player hazard | Diffuses propagation |
| Lava | Passable | Falls and flows like a slow viscous liquid; side-up overflow is slow and ignores small fill differences; fills its lethal hazard meter from 10% fill, with low-fill lava building the meter more slowly than a full hex | Detonates bombs |

Moving terrain cells store a 0-255 fill amount. A cell keeps one terrain type, but
partial fill controls movement and rendering. Terrain simulation advances as a
six-pass cellular automata tick spread across six frames: vertical even,
down-right even, down-left even, then the same three odd connection pairs. Each pair resolves
from its two source cells so a cell is not written by multiple pairs in one pass.
Block density, configured on terrain definitions, resolves fall and displacement
priority rather than terrain IDs. Water/lava contact creates stone whenever both
have nonzero fill. The renderer uses the completed even phase only to bridge proven
vertical liquid falls in the final state. Simulation and presentation work remain spread across frames so
player physics, projectiles, and input stay responsive.

## Player And Camera

- The player is about two hexes tall and can step up low hex slopes.
- Movement includes ground acceleration, air control, coyote time, jump buffering,
  and floor support probing.
- The hook attaches only to hookable terrain within its configured range.
- `A/D` adds tangential momentum while hooked without forcing same-direction
  overspeed back to walk or air speed caps; `W/S` adjusts rope length.
- The camera remains horizontally fixed and zooms so the map width fills the
  viewport. It never scrolls upward during a run.

The player dies when a hazard meter fills, from a bomb's lethal radius, or by falling
below the world. A full lava hex fills in 0.2 seconds; lava from its 10% activation
threshold ramps linearly from 10% to full meter-fill speed as terrain fill rises. Suffocation
fills while the head has no breathable Air: a partially filled head hex samples the
hex above it, while a full non-Air hex blocks breathing. Hazard meters recover over
time after escape, with lava recovering in one second and suffocation in three.
Death never records current depth.

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

- Current art is original repository content; runs show a sky gradient above depth
  0, a grass transition band on the surface edge, and a graded, tiled cave texture
  below it. Stone and dirt terrain use looping world-space textures, while other
  terrain surfaces are procedurally styled. Terrain boundaries have rounded,
  deterministic irregularity: denser terrain visually takes mixed-material seams,
  while matching terrain can round outward into concave gaps.
- Water, lava, sand, stone, and dirt must remain distinguishable by pattern and shape,
  not color alone. Partial moving cells show their fill level with smoothed surfaces
  between matching neighboring moving terrain; if a partial moving cell has liquid
  above, the empty portion draws that liquid, and if it has solid above, it renders
  as a full hex of its own material.
- `AudioDirector`, `GameplayFeedback`, and camera shake are presentation only and must
  not own gameplay decisions.
- Lighting diffuses through neighboring hexes using the emitting hex's
  terrain-specific coefficient. The surface row starts fully lit.
  Lava emits light and the player emits a stronger moving light. Light at or above
  the exploration threshold is permanent; dim unsupported light fades. Player-local
  diffusion advances every terrain pass, while the rest of the map advances once per
  six-pass terrain tick. World rendering is black through light level 30, grades to
  full brightness by 160, and keeps fully dark air opaque so the cave backdrop does
  not leak through unexplored space.
- Keyboard/mouse, touch, and standard gamepad controls are supported. Phone controls
  target fullscreen landscape Web play now; future native Android and iOS builds use
  the same control behavior.

## Feature Invariants

New features may change balance and presentation, but should preserve these unless
this document is deliberately revised:

- Only a valid planted flag creates a score.
- The same seed creates the same initial map.
- Terrain and item behavior remains resource-driven and type-agnostic at call sites.
- No per-cell scene nodes are introduced.
- Simulation work does not stall frame-by-frame input and physics.
- Web remains a supported release target.
