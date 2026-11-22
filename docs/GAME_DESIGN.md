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
   action buttons, a corner leaderboard owner, and Help, Settings, and Statistics
   pages for rules, controls, device preferences, and lifetime statistics.
2. Starting creates a randomized deterministic map, settles it for 50 six-pass terrain-simulation ticks while loading, and prepares a fresh inventory.
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
| Left stick | Move horizontally; when free, push up to jump; while swinging from terrain, push up/down to shorten/lengthen the rope. While the hook holds a barrel, push up still jumps |
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
briefly shows the item name above the toolbar. A newly selected slot pops, or shakes
when its item is empty; an empty item is dimmed with a red count. A slot pulses gold
when its item is gained and its icon squashes when the item is used.
The top-left depth and personal-best readout is outlined so it reads over sky and
cave. It bumps while the player descends, a short toast marks every 50 depth, and the
first time a run goes deeper than the saved personal best the readout turns gold with
a "Deeper than your best!" toast.
A live integer FPS reading appears with the top-left run status during active play in
all release and debug builds so device performance can be compared directly.
Collected perks appear as an icon stack above that status; hovering an icon shows its
name and effect. A newly gained perk icon pops in. The stack wraps before the hazard
display.
Jelly removes impact damage and knockout, makes the player float in liquids, enables
jumping from the liquid surface, rebounds from meaningful hard-surface landings, and
lets explosions throw the player without changing their lethal radius. Small residual
contacts settle normally so walking and ground jumping remain responsive.
A compact pause button opens the pause menu, which contains Resume, Restart, and
Back to Menu actions together with in-run access to the same Help and Settings
panels as the main menu. Closing either panel returns to the paused run.

Active hazards appear as an icon-only stack of filling bars at the top center. A bar
pops in when its hazard starts. Building bars pulse with a gold warning outline; past
half full they pulse faster, glow red, and shake harder the closer they are to full.
Recovering bars are calm and dimmed with a downward indicator, and an emptied bar
fades out. The stack is generic so future terrain hazards can add their own icon and
color without HUD-specific logic.

The first second of a run blocks throws so the Start click cannot fire an item.

## World

- The default map is 100 columns by 512 rows of flat-top hexes.
- The bottom 6% depth band is filled with lava. Its upper 1% softly blends into the
  generated cave while the bottom edge remains completely filled. The space beside
  and below the generated hex grid is solid to players and terrain-aware objects.
  The space above the top row is open sky between the side walls, so the player can
  climb out of the cave and walk on top of the map.
- The camera is horizontally locked to the map and follows downward. If upward
  movement carries the player above the screen, it slowly recovers upward until the
  player has two hexagons of visible space above them.
- Initial terrain is deterministic for a given seed.
- Before the player and generated containers enter the run, loading advances the generated terrain through 50 complete simulation ticks (300 GPU passes). The loading status reports settlement progress, and gameplay begins only after the final committed tick.
- Generation uses an ordered resource-driven pass stack. The shipped default stack
  layers base cave noise, typed hazard pocket instances for sand/water/lava/sulfur, a
  noisy surface spawn shaft, item chest, geode, and explosive barrel chambers, and a
  bottom lava fill.
- The player starts at surface depth 0 in a roughly six-cell-wide zig-zag shaft
  with noisy edges and occasional broken segments that winds down to the configured
  shaft target depth.
- The generation profile and pass tuning live in
  `config/generation/default_profile.tres`.

### Terrain Rules

| Terrain | Collision | Motion/hazard | Bomb response |
| --- | --- | --- | --- |
| Air | Passable | Pressure-balancing breathable gas; normal pressure is 64 quantity | None |
| Stone | Solid | Stable | Becomes dirt |
| Dirt | Solid | Stable | Becomes sand |
| Sand | Solid at half fill or more | Falls and creeps side-down; denser Sand displaces lighter moving terrain into a conserved hidden component that escapes through later pair passes; pushes the player out rather than burying them, with any resulting player velocity change evaluated as an impact | Becomes air |
| Water | Passable | Falls and flows quickly side-down and side-up by CA fill offset; mildly damps immersed player motion and contributes no terrain-specific player hazard | Diffuses propagation |
| Lava | Passable | Falls and flows like a slow viscous liquid; side-up overflow is slow and ignores small fill differences; strongly damps immersed player motion and fills the shared Cooked meter from 10% fill, with low-fill lava building it more slowly than a full hex | Detonates bombs |
| Steam | Passable | Breathable buoyant gas that rises through Air without condensing, levels out under ceilings like an upside-down liquid, and escapes through the open top of the map. Normal pressure is 63 quantity; pressure above it spreads sideways and, once no higher exit remains, downward. Contact slowly fills the shared Cooked meter | None |
| Sulfur | Solid | Static yellow mineral. Water slowly converts it and nearby water into sulfuric acid; Lava permanently ignites it, consuming it into sulfur dioxide | Becomes air and emits sulfur dioxide |
| Sulfuric Acid | Passable | Dense yellow-green liquid that sinks beneath water and consumes sand below it into water; contact fills a lethal Acid meter | None |
| Sulfur Dioxide | Passable | Heavy yellow-green gas. One bar is 63 quantity, with four bars maximum; it settles through air and only overpressure rises. Contact fills a Poison meter and blocks breathing | None |

Terrain cells store a visible primary material and may temporarily retain one
invisible, less-dense secondary material during displacement. Each component owns
its quantity independently. Sand, Water, and Lava are visibly full at 127;
quantities from 128 through 255 represent hidden overpressure. Air is an invisible
gas: 64 quantity is normal atmospheric pressure and 255 is the packed pressure
ceiling. Pair passes first evacuate displaced secondary material into compatible
neighbors; when none is available, its quantity pressure-balances into full
same-material neighbors over later passes. Simulation transfers conserve Air,
Sand, Water, Lava, and Steam quantities. Explicit gameplay mutations, authored
reactions, and Steam venting through the top edge remain intentional sources or
sinks. Terrain simulation advances at a
fixed 60 cellular-automata passes per real second, forming ten six-pass ticks per
second: vertical even, down-right even, down-left even, then the same three odd
connection pairs. Each pair resolves
from its two source cells so a cell is not written by multiple pairs in one pass.
Block density, configured on terrain definitions, resolves fall, component ordering,
and displacement priority rather than terrain IDs. Once per tick, each Water cell
touching any amount of Lava converts Water to Steam at its resource-configured rate.
The default converts one Water quantity into ten Steam quantity and averages 127 Steam
quantity per second; it pauses when the Water cell has no component capacity for the
expanded Steam. Lava remains unchanged. Only the primary component
affects rendering, collision, hazards, viscosity, and item contact.
The out-of-bounds space below the final map row behaves as solid terrain, so fluids
can settle and spread along the bottom edge without leaving the world. The space
above the top map row is open sky: Steam in the top row keeps rising and leaves the
world, while every other terrain stays inside.
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
- The hook attaches to hookable terrain or to an explosive barrel within its
  configured range, whichever the hook ray reaches first.
- `A/D` adds tangential momentum while hooked without forcing same-direction
  overspeed back to walk or air speed caps; `W/S` adjusts rope length.
- The camera remains horizontally fixed and zooms so the map width fills the
  viewport. It tracks descent immediately; upward recovery starts only after the
  player leaves the top of the screen and moves slowly until two hexagons are visible
  above the player.

The player dies when a hazard meter fills, from a high-speed terrain impact, or from a
bomb's lethal radius. Lava and Steam share the Cooked meter. A full Lava hex fills it in 0.2
seconds; Lava from its 10% activation threshold ramps linearly from 10% to full
meter-fill speed as terrain fill rises. Normal-pressure Steam fills it in five seconds
and higher pressure does not exceed that rate. Suffocation fills while the head has no
breathable terrain: a partially filled head hex samples the hex above it, while a full
non-breathable hex blocks breathing. Steam and Air are breathable; any Sulfur Dioxide
blocks breathing. Acid fills in 1.5 seconds from 10% fill and Poison
fills in 10 seconds from any amount, reaching full rate at one SO₂ bar. Both recover
over their respective fill durations; Cooked recovers in one second and both impact
and suffocation recover from full in three. Sulfur Resistance makes SO₂ breathable,
prevents Poison, and adds two seconds to Acid survival. Heat Resistance adds one second
to both Lava and Steam Cooked exposure; Glass Cannon is immune to
all terrain hazards and suffocation. Death never records current depth.

## Items

Every run starts with 10 small bombs, 2 large bombs, and 1 flag. Pickaxes, shovels,
flares, Water Bottles, Acid Bottles, and Excavators start at zero and are found in chests. Item
tuning lives under `config/items/`. A thrown item appears in the world as its toolbar
icon and turns to follow its flight; the flag flies pole tip first with its banner up.

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
- Acid Bottle: follows the same bottle behavior but fills the nearest three Air
  hexes with Sulfuric Acid.

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
- A resting chest notices terrain changing under or around it within 0.1 seconds
  while it is inside the camera view or up to 12 hex radii outside it, and within
  1 second farther away. A chest enclosed with no fitting Air in range looks again
  within 1 second of nearby terrain changing. Terrain edited by an item wakes the
  affected chests immediately. A late reaction only delays when a chest starts to
  move; it then falls and settles by the same rules as a chest in view.
- Item chests emit the same light level as Lava (90). Their light uses normal
  terrain diffusion and fades after collection because it is below the permanent
  exploration threshold.
- Touching a chest pauses player, projectile, hazard, and terrain activity until a
  reward is chosen. The picker cannot be dismissed without choosing.
- Chests offer two unique rewards drawn from 5 small bombs, 2 large bombs, 120
  shovel charge, 50 pickaxe charge, 10 flares, 3 Water Bottles, 3 Acid Bottles,
  and 1 Excavator.
- Claiming a choice adds its quantity without changing the selected inventory item,
  then removes that chest for the rest of the run.
- A bomb's lethal core arms a chest for a 0.30-second delayed detonation. An armed
  chest cannot be claimed, continues moving and emitting light, then explodes with
  its independently tunable Small Bomb-sized effect and grants no reward.

### Explosive Barrels

Speeds below are in world units per second; one hex is 16 units in radius.

- Explosive barrels are distributed deterministically from 10% through 88% of map
  depth by the same jittered grid areas as chests: two columns, 40-row areas, a
  20-row stagger, and a 50% per-area chance, giving 21 opportunities and usually
  8 to 13 barrels on the default map.
- An area places its barrel only on an anchor whose cell below and both lower
  neighbors are solid, with no Lava or Sulfuric Acid within two hexes, so barrels
  start at rest and never start touching a trigger. An area without such an anchor
  has no barrel. The barrel carves a radius-one chamber to Air at and above its anchor.
- Barrels are round bodies 1.2 hex radii in radius. They fall under 880 gravity up to
  720 units/s, keep 20% of their speed into a surface as a small bounce, roll down
  slopes steeper than 15 degrees, and slow under ground friction.
- Barrels are not solid to the player. Walking into one pushes it aside without
  slowing the player; the barrel takes 90% of the player's horizontal speed, up to
  260 units/s.
- The hook can hold a barrel; the rope runs to its center. The player is never swung
  or held back by a barrel: walking, jumping, and air control work as when unhooked.
  Whenever the player is farther away than the rope length, the barrel is pulled
  toward the player at 1600 units/s² up to 420 units/s along the rope, so walking away
  or shortening the rope reels it in. Touch controls keep push-up as a jump while
  holding a barrel, so touch players pull a barrel by moving away from it. The hook
  releases when the barrel explodes.
- A barrel explodes at once when Lava or Sulfuric Acid touches its body at a fill that
  makes that terrain hazardous, or when a collision changes its speed by 650 units/s
  or more: a free fall of about nine hexes, or being blasted into a wall.
- An explosion arms every barrel whose hex lies within its blast radius, counted in
  hex steps from the explosion's hex like terrain damage, and a lethal-core overlap
  arms one too. An armed barrel explodes after a 0.30-second chain fuse, so a barrel
  explosion reaches other barrels within ten hexes one fuse at a time. Armed barrels
  keep moving and still explode at once on a trigger.
- The barrel explosion has its own tuning, currently equal to the Large Bomb: blast
  radius 10, lethal and player-kill radius 6, and a 1280 impulse with large feedback.
  It also releases 7620 quantity (about 121 bars) of Sulfur Dioxide at its center,
  filling the vaporized core with overpressured gas that then rises and spreads.
- Resting barrels notice terrain changes like chests: within 0.1 seconds in view or
  up to 12 hex radii outside it, within 1 second farther away, and immediately for
  terrain edited by an item. A barrel resting in Water or another non-Air fluid checks
  every 0.1 seconds wherever it is. Pushes, hook pulls, and blasts move a resting
  barrel at once.
- Pausing and the reward picker freeze barrels, their chain fuses, and pushing.

### Bombs

- Bombs follow projectile gravity and bounce until their fuse expires.
- Small bombs are tuned for a longer throw than large bombs.
- Terrain inside the lethal radius is vaporized to air regardless of type.
- Outside the lethal radius, terrain uses its configured blast reaction.
- Lava detonates a bomb immediately; water reduces blast propagation.
- Bombs and chests share the same explosive behavior. A lethal-core overlap arms
  another explosive for a 0.30-second chain fuse; the wider blast alone cannot start
  a chain, except for explosive barrels. Armed bombs keep moving, and their natural
  fuse still wins if it expires first.
- Explosions apply a distance-falloff impulse across their blast radius to airborne
  projectile bodies, including bombs and the flag, and to explosive barrels.
- The player dies when inside the lethal radius.
- A destroyed full Sulfur hex releases 150 SO₂ bars. Small Boom adds a 45-bar
  cloud to Small Bombs; Large Boom adds two. Sulfur converts up to ten times its
  own quantity of Water into equal-quantity Acid before depleting. Gas first fills nearby
  SO₂ and Air cells, then uses compatible secondary components if needed.
- Existing SO₂ inside a vaporize core is displaced to the first ring outside that
  core; its quantity is conserved rather than destroyed.

### Excavator

- The Excavator lands as a tall industrial walking drill with an exposed front auger, articulated legs, and an orange mining rig body. It then clears a three-wide shaft every half-second for twenty seconds.
- It uses the same terrain-aware rigidbody behavior as thrown items: it falls onto support and receives blast-pulse impulses.
- A lethal-core blast arms its short chain fuse and detonates its configured explosive effect.

### Flag

- The flag is thrown using projectile physics and does not bounce.
- It ignores water, is destroyed by lava or Sulfuric Acid at 10% fill or more, and sticks on its first valid solid
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

## Statistics

The main-menu Statistics page shows lifetime totals kept only on this device. They
are stored apart from scores and are never submitted.

- Every started run counts as a run, including runs abandoned through Restart or
  Back to Menu. A run counts as a played game once the player reached depth 30.
- Lifetime tiles: games played, flags planted, victories, best and current flag
  streak (consecutive played games with a planted flag), time played, deepest depth
  with the deepest planted flag, total depth traveled (the deepest point of each run,
  added together), and deaths.
- A planted flag counts when it lands, whether or not a name is then confirmed. The
  score itself is still saved only after name entry.
- A victory is a flag planted in Earth's lava core: at or below 95% of the world
  depth. Only a flag protected by the Relentless perk survives there. The result
  screen marks a victory.
- Relentless can record both a death and the dropped flag's outcome in one run.
- Loot and flags: chests and geodes opened, chests and geodes destroyed by a blast before
  being claimed, explosive barrels exploded, and flags lost by cause (lava or acid).
- Items: times each item was used and how often it was picked from the chest offers
  that included it. Perks: times each perk was picked out of its geode offers.
- Causes of death are ranked with their share of all deaths.
- Totals are written when a run ends. Missing or corrupt statistics read as empty.

## Presentation

- Current art is original repository content; runs show a sky gradient above depth
  0, a grass transition band on the surface edge, and a graded, tiled cave texture
  below it. Stone and dirt terrain use looping world-space textures, while other
  terrain surfaces are procedurally styled. Terrain boundaries have rounded,
  deterministic irregularity: denser terrain visually takes mixed-material seams,
  while matching terrain can round outward into concave gaps.
- Water, lava, sand, stone, and dirt must remain distinguishable by pattern and shape,
  not color alone. Partial moving cells show their fill level with smoothed surfaces
  between matching neighboring moving terrain. If a partial moving cell has liquid
  or gas above, its empty portion draws that material; solid terrain above does not
  fill the empty portion.
- The player is an animated explorer who idles, walks, runs, jumps, falls, crouches
  on hard landings, swims while afloat in liquid, and digs while burrowing through
  sand. A knocked-out body goes limp: it tumbles in flight, rolls along the ground
  with its speed, drops flat once it slows down, and gets up through a crouch. A dark
  outline keeps the body readable against the cave. The hook is a steel claw on a
  braided rope that leaves from the hand. It flies out with its jaws open and the rope
  waving behind it, snaps shut on whatever it bites with a short shiver of the rope,
  and follows a hooked barrel. A rope under load is straight. A hook that finds
  nothing reaches its full range and falls back to the hand, and a released hook
  whips back instead of vanishing. A standing body reaches for the hook point; a swinging body leans
  along the rope and holds it overhead on its center line, so the rope does not move
  when the character turns around. The character faces its direction of travel, or the hook when standing still.
- `AudioDirector`, `GameplayFeedback`, and camera shake are presentation only and must
  not own gameplay decisions.
- Explosions show a white core flash, a fireball that cools from white-yellow through
  orange to dark red, a shockwave ring, sparks and debris that fall with gravity,
  smoke, and a short afterglow. Everything scales with the blast radius; large
  explosions add a second ring, fire tongues, embers, and a taller smoke column. The
  explosion's effect color tints the fire. Effects glow in unlit caves.
- The camera shakes with nearby explosions, hard impacts, and death. Stronger and
  closer causes shake more, causes far off screen do not shake, and the camera is
  briefly pushed away from a blast. Shake never shows the area below the map.
- Player moments have world effects: dust on jumps and on real landings (not on
  steps while running), a ring on air jumps, an impact flash, stars circling a
  knocked-out explorer for as long as the knockout lasts, hook launch streaks, sparks
  and chips where the hook bites (a ring on a moving target), splashes in the
  liquid's color, sand bursts, a pulse in the hazard's meter color while a hazard
  warns, and a death burst with a cause-specific addition.
- Item and world moments have world effects: a throw whoosh, a tool swing arc with
  chips, bounce sparks, a burn-out fizzle, glass and liquid from a broken bottle,
  closing red rings on a lit chain fuse, planks, crystal, or metal from a destroyed
  chest, geode, or barrel, dust under a bumping barrel, excavator landing and drill
  debris, bursts when a container opens and when a reward is claimed, a burst and a
  flag that stays planted where the flag lands, a cause-specific puff when the flag
  is destroyed, and confetti with light rays on victory.
- Interface motion is short (about 0.1 to 0.3 seconds), never delays input, and never
  changes what a control does. Buttons grow slightly on hover or focus, shrink while
  pressed, and show a light outline when focused. Menus, pages, and panels pop in with
  staggered buttons. Starting a run and returning to the menu fade in from darkness;
  loading shows a progress bar under the status line and dims the menu buttons.
  Pause, name entry, results, and the reward picker dim the world behind them, with a
  red tint on a lost run, and the dim fades out when play resumes.
- Reward cards deal in one after another. The chosen card swells and lifts away while
  the others fade, without delaying the resumed run.
- Name entry counts the planted depth up from zero. A depth beyond the saved personal
  best is marked "New personal best!" on name entry and, once confirmed, on the result
  panel. A lost run shows its title in red with a shake.
- The Statistics page reveals its sections top to bottom; whole-number values count up
  and bars grow to their share.
- A held touch stick brightens, and the hook ring thickens while the hook is held.
- Every feedback moment has a synthesized sound effect; there is no music yet.
  Explosions are the loudest sounds and grow lower and louder with their blast
  radius; a large blast is longer and deeper than a small one. Interface sounds are
  the quietest. Landings sound only after real air time or a fast fall and get
  heavier with impact speed, so running across hex steps is silent. Slow bounces,
  gentle barrel bumps, and slow wading are silent too. The hook has its own launch,
  bite (duller on a barrel), miss, release, and torn-off sounds. Each death cause has
  its own sting over a shared falling motif, and the hazard warning rises in pitch and
  doubles its pulse as the meter fills. Chests, geodes, and barrels break and open with
  wood, crystal, and metal sounds. Repeated sounds vary slightly in pitch and volume,
  and sounds far from the screen centre are quieter.
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
