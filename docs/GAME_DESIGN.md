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
4. Touching generated item chests pauses the run and offers a mandatory choice of supplies. Lootable purple geodes use the same choice flow to offer permanent, unique perks instead; destroying one drives a purple, front-loaded 5-wide pulse 20 hexes downward over 1.6 seconds.
5. The player throws the flag when ready to claim a depth.
6. A valid landing opens editable name entry and saves/submits the score.
7. Death or a flag destroyed by lava ends the run without saving its depth.
8. The player restarts with a new seed or returns to the menu.

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
| `1`–`8` | Select the matching inventory slot; collected dynamic items occupy keys 4–8 in acquisition order |
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

Settings also provides a five-position frame limiter: 30, 60, 90, 120, or
Unlimited FPS. It defaults to 30 FPS on native mobile and mobile Web builds, and to
Unlimited on desktop and in the editor. The choice affects presentation frame rate,
not terrain speed, and is saved independently from the Phone Controls preference.

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
Collected perks appear as an icon stack above that status; hovering an icon shows its
name and effect. The stack wraps before the hazard display.
Jelly removes impact damage and knockout, makes the player float in liquids, enables
jumping from the liquid surface, rebounds from meaningful hard-surface landings, and
lets explosions throw the player without changing their lethal radius. Small residual
contacts settle normally so walking and ground jumping remain responsive.
A compact pause button opens the pause menu, which contains Resume, Restart, and
Back to Menu actions together with in-run access to the same Help and Settings
panels as the main menu. Closing either panel returns to the paused run.

Active hazards appear as an icon-only stack of filling bars at the top center. Building
bars pulse with a gold warning outline; recovering bars are dimmed with a downward
indicator. The stack is generic so future terrain hazards can add their own icon and
color without HUD-specific logic.

The first second of a run blocks throws so the Start click cannot fire an item.

## World

- The default map is 100 columns by 512 rows of flat-top hexes.
- The bottom 6% depth band is filled with lava. Its upper 1% softly blends into the
  generated cave while the bottom edge remains completely filled. Horizontal escape
  is prevented by invisible player bounds.
- The camera is horizontally locked to the map and follows downward. If upward
  movement carries the player above the screen, it slowly recovers upward until the
  player has two hexagons of visible space above them.
- Initial terrain is deterministic for a given seed.
- Generation uses an ordered resource-driven pass stack. The shipped default stack
  layers base cave noise, typed hazard pocket instances for sand/water/lava, a
  noisy surface spawn shaft, item chest chambers, and a bottom lava fill.
- The player starts at surface depth 0 in a roughly six-cell-wide zig-zag shaft
  with noisy edges and occasional broken segments that winds down to the configured
  shaft target depth.
- The generation profile and pass tuning live in
  `config/generation/default_profile.tres`.

### Terrain Rules

| Terrain | Collision | Motion/hazard | Bomb response |
| --- | --- | --- | --- |
| Air | Passable | Pressure-balancing gas; normal pressure is 64 quantity | None |
| Stone | Solid | Stable | Becomes dirt |
| Dirt | Solid | Stable | Becomes sand |
| Sand | Solid at half fill or more | Falls and creeps side-down; denser Sand displaces lighter moving terrain into a conserved hidden component that escapes through later pair passes; pushes the player out rather than burying them, with any resulting player velocity change evaluated as an impact | Becomes air |
| Water | Passable | Falls and flows quickly side-down and side-up by CA fill offset; mildly damps immersed player motion and contributes no terrain-specific player hazard | Diffuses propagation |
| Lava | Passable | Falls and flows like a slow viscous liquid; side-up overflow is slow and ignores small fill differences; strongly damps immersed player motion and fills its lethal hazard meter from 10% fill, with low-fill lava building the meter more slowly than a full hex | Detonates bombs |

Terrain cells store a visible primary material and may temporarily retain one
invisible, less-dense secondary material during displacement. Each component owns
its quantity independently. Sand, Water, and Lava are visibly full at 127;
quantities from 128 through 255 represent hidden overpressure. Air is an invisible
gas: 64 quantity is normal atmospheric pressure and 255 is the packed pressure
ceiling. Pair passes first evacuate displaced secondary material into compatible
neighbors; when none is available, its quantity pressure-balances into full
same-material neighbors over later passes. Simulation transfers conserve Air,
Sand, Water, and Lava quantities. Explicit gameplay mutations and Water/Lava
contact remain intentional sources, sinks, or reactions. Terrain simulation advances at a
fixed 60 cellular-automata passes per real second, forming ten six-pass ticks per
second: vertical even, down-right even, down-left even, then the same three odd
connection pairs. Each pair resolves
from its two source cells so a cell is not written by multiple pairs in one pass.
Block density, configured on terrain definitions, resolves fall, component ordering,
and displacement priority rather than terrain IDs. Water/lava contact creates stone
whenever both have nonzero quantity in either component. Only the primary component
affects rendering, collision, hazards, viscosity, and item contact.
The out-of-bounds space below the final map row behaves as solid terrain, so fluids
can settle and spread along the bottom edge without leaving the world.
The renderer uses the completed even phase only to bridge proven
vertical moving-terrain falls, including sand and liquids, in the final state. High
frame rates skip simulation work;
low frame rates may submit the remaining passes of one tick as an ordered batch.
This keeps terrain speed independent from the presentation frame rate while player
physics, projectiles, and input remain frame-responsive.

## Player And Camera

- The player is about two hexes tall and can step up low hex slopes.
- Movement includes ground acceleration, air control, coyote time, jump buffering,
  and floor support probing.
- Glass Cannon disables horizontal control during unsupported free flight, while
  retaining normal `A`/`D` swing control whenever the grappling hook is attached.
- Glass Cannon and either Hard Skin or Jelly mutually cancel their impact changes,
  restoring the normal fall-damage and knockout thresholds. Acrobat and Glass
  Cannon similarly offset their rope-length, gravity, and free-air-control changes
  back to baseline.
- Fluid viscosity damps the player's complete velocity, including walking, jumping,
  falling, swinging, ragdoll motion, and carried impulses. Drag scales with committed
  cell fill and the fraction of the three-point body sample immersed; Water has mild
  resistance and Lava has strong resistance. Fluid drag is not itself an impact.
- Terrain impacts use the magnitude of velocity removed or redirected by collision,
  grapple correction, or escape from newly solid terrain. The greatest change in a
  physics frame contributes its amount above the configured safe-impact speed to a
  visible meter. The meter recovers to empty over three seconds from full, marks the
  knockout threshold within the bar, and marks death at its end. Repeated nearby
  impacts accumulate; reaching the medium threshold knocks the player into a
  one-second uncontrolled tumble and detaches the hook, while reaching the end kills
  the player. A single impact at either threshold retains the same outcome.
- When solid terrain overlaps the player, escape targets only an Air position where
  the complete player body fits. Cramped one-row gaps are skipped, and the push is
  applied over consecutive physics frames until the overlap is cleared. If no such
  Air position is in the configured search range, the player is not pushed through
  terrain.
- The hook attaches only to hookable terrain within its configured range.
- `A/D` adds tangential momentum while hooked without forcing same-direction
  overspeed back to walk or air speed caps; `W/S` adjusts rope length.
- The camera remains horizontally fixed and zooms so the map width fills the
  viewport. It tracks descent immediately; upward recovery starts only after the
  player leaves the top of the screen and moves slowly until two hexagons are visible
  above the player.

The player dies when a hazard meter fills, from a high-speed terrain impact, from a
bomb's lethal radius, or by falling below the world. A full lava hex fills in 0.2
seconds; lava from its 10% activation threshold ramps linearly from 10% to full
meter-fill speed as terrain fill rises. Suffocation fills while the head has no
breathable Air: a partially filled head hex samples the hex above it, while a full
non-Air hex blocks breathing. Hazard meters recover over time after escape, with
lava recovering in one second and both impact and suffocation recovering from full
in three. Death never records current depth.

## Items

Every run starts with 10 small bombs, 2 large bombs, and 1 flag. Pickaxes, shovels,
flares, Water Bottles, and Excavators start at zero and are found in chests. Item
tuning lives under `config/items/`.

- Pickaxe: changes an aimed triangular three-hex wedge of Stone to Dirt or Dirt to
  Sand. Its charge follows target fill, capped at three per use; a final partial
  charge still completes a valid use.
- Shovel: clears an aimed triangular three-hex wedge of Sand with the same charge rules.
- Flare: is thrown farther than a small bomb, bounces as a visible rotating rod,
  lights the cave for ten seconds, and breaks on lava. The newest active flare uses
  the second high-frequency light slot alongside the player.
- Water Bottle: uses the small bomb's ballistic throw, then breaks on a solid impact
  to fill the nearest three Air hexes with Water; it breaks without depositing when
  it hits lava.

### Item Chests

- Item chests are distributed deterministically from 5% through 90% of map depth by
  jittered grid areas. The default uses two columns, 50-row areas, a 25-row stagger,
  and a 100% per-area chance, producing 19 opportunities on the default map.
- Each area chooses its anchor independently, so neighboring chests may appear close
  together while exact duplicate anchors are prevented.
- Each chest occupies a radius-three chamber carved to Air at and above its anchor;
  the generated terrain below is preserved as its natural landing surface.
- Chests fall straight down without bouncing or sliding. They remain upright in the
  air and snap to a 45-degree lean when only one side has level support.
- Chests remain non-solid touch triggers. Like the player, a chest embedded by moving
  terrain escapes toward the nearest Air position where its complete rectangular
  body fits instead of remaining buried.
- Item chests emit the same light level as Lava (90). Their light uses normal
  terrain diffusion and fades after collection because it is below the permanent
  exploration threshold.
- Touching a chest pauses player, projectile, hazard, and terrain activity until a
  reward is chosen. The picker cannot be dismissed without choosing.
- Chests offer two unique rewards drawn from 5 small bombs, 2 large bombs, 120
  shovel charge, 50 pickaxe charge, 10 flares, 3 Water Bottles, and 1 Excavator.
- Claiming a choice adds its quantity without changing the selected inventory item,
  then removes that chest for the rest of the run.
- A bomb's lethal core arms a chest for a 0.30-second delayed detonation. An armed
  chest cannot be claimed, continues moving and emitting light, then explodes with
  its independently tunable Small Bomb-sized effect and grants no reward.

### Bombs

- Bombs follow projectile gravity and bounce until their fuse expires.
- Small bombs are tuned for a longer throw than large bombs.
- Terrain inside the lethal radius is vaporized to air regardless of type.
- Outside the lethal radius, terrain uses its configured blast reaction.
- Lava detonates a bomb immediately; water reduces blast propagation.
- Bombs and chests share the same explosive behavior. A lethal-core overlap arms
  another explosive for a 0.30-second chain fuse; the wider blast alone cannot start
  a chain. Armed bombs keep moving, and their natural fuse still wins if it expires first.
- Explosions apply a distance-falloff impulse across their blast radius to airborne
  projectile bodies, including bombs and the flag.
- The player dies when inside the lethal radius.

### Excavator

- The Excavator lands as a tall industrial walking drill with an exposed front auger, articulated legs, and an orange mining rig body. It then clears a three-wide shaft every half-second for twenty seconds.
- It uses the same terrain-aware rigidbody behavior as thrown items: it falls onto support and receives blast-pulse impulses.
- A lethal-core blast arms its short chain fuse and detonates its configured explosive effect.

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
- Reward cards support mouse/touch, keyboard number keys, and standard gamepad UI
  focus and confirmation.

## Feature Invariants

New features may change balance and presentation, but should preserve these unless
this document is deliberately revised:

- Only a valid planted flag creates a score.
- The same seed creates the same initial map.
- Terrain and item behavior remains resource-driven and type-agnostic at call sites.
- No per-cell scene nodes are introduced.
- Simulation work does not stall frame-by-frame input and physics.
- Web remains a supported release target.
