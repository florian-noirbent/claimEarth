# Claim Earth - Game Design Document

## 1. Product

**Claim Earth** is a fast, cartoon side-scrolling arcade game for modern desktop
browsers. The player descends through a newly generated hexagonal cave, using a
grappling hook and a limited supply of bombs. A run scores only when the player
throws and safely plants the flag. Dying or losing the flag discards the run.

Jam theme: **Center of Earth**.

### Design pillars

1. **Risk the depth** - every extra meter improves the score but risks losing it.
2. **Movement is the toy** - walking, jumping, air control, and rope momentum must
   remain enjoyable before hazards or scoring are added.
3. **Readable chain reactions** - terrain movement and bomb transformations must
   be predictable from color, shape, animation, and sound.
4. **Short, replayable runs** - generation and restart are quick, with no account
   creation or mandatory setup.

## 2. Release Scope

The jam release includes:

- Procedural 100 by 2000 flat-top hex maps.
- Air, stone, dirt, sand, water, and lava.
- Walking, jumping, air control, grappling, rope adjustment, and swinging.
- Small bombs, large bombs, terrain destruction, and chain reactions.
- Flag planting, local personal best, and SimpleBoards global leaderboard.
- Main menu, gameplay HUD, name entry, leaderboard, death, and restart flows.
- Cartoon vector graphics, procedural terrain texture, effects, and audio.
- Automated unit, integration, deterministic generation, and web smoke tests.

Desktop keyboard and mouse are required. Touch controls, gamepads, enemies,
upgrades, accounts, an infinite world, and mobile-browser optimization are out of
scope for the jam release.

## 3. Core Loop

1. Main menu displays a live cave background and `Earth owned by: {leader}`.
2. Start creates a random seed, generates the world, and spawns the player safely.
3. The player descends using movement, the hook, and limited bombs.
4. The player chooses whether to risk going deeper or plant the flag.
5. A thrown flag locks out other item throws until it resolves.
6. Lava destroys the flag and invalidates the run. A valid landing freezes the
   run and opens name entry.
7. Name entry is prefilled with the last submitted name and remains editable.
8. Confirming saves the local best when applicable and submits the score online.
   Network failure never loses the local result.
9. The result screen offers an immediate new randomized run or the main menu.

## 4. World

### Hex grid

- Orientation: flat-top hexagons.
- Logical size: 100 columns by 2000 rows.
- Scale: one hex diameter is one gameplay unit; the player is approximately two
  units tall.
- Coordinates use axial coordinates internally and offset coordinates for compact
  rectangular storage.
- Horizontal edges are sealed by indestructible boundary cells.
- The final two map rows are indestructible stone.
- Depth is measured from the surface spawn line to the flag's final grid row.

### Terrain

| Terrain | Collision | Simulation | Hazard | Bomb transformation |
| --- | --- | --- | --- | --- |
| Air | Passable | Stable | None | No change |
| Stone | Solid | Stable | None | Becomes dirt |
| Dirt | Solid | Stable | None | Becomes sand |
| Sand | Solid | Falls; swaps downward with water/lava | Burial | Becomes air |
| Water | Passable | Falls, then spreads sideways | Suffocation | Diffuses blast |
| Lava | Passable | Falls, then spreads sideways | Instant death | Detonates bomb |

When lava enters water, or water enters lava, the destination cell becomes stone.
The visual and audio response must make this conversion obvious.

Environmental simulation commits at 0.5-second intervals. Player movement,
projectiles, blast damage, lethal contact, and rendering remain frame-responsive.

### Procedural generation

Each run stores and exposes its seed for reproduction.

1. Fill the map with stone.
2. Sample multi-octave gradient noise with a stronger horizontal frequency than
   vertical frequency to create layered, horizontally biased caves.
3. First pass assigns stone, dirt, and air using configurable thresholds.
4. Second independent pass overrides eligible areas with sand, water, and lava
   pockets using depth-dependent frequencies and thresholds.
5. Carve and validate a safe surface spawn chamber.
6. Seal side boundaries and the final two rows with indestructible stone.
7. Reject or repair generations that fail configured spawn-space and early-route
   checks.

Generation must not promise that every map is fully traversable. Resource use,
route reading, and choosing when to plant are part of the game.

## 5. Player

### Controls

| Input | Action |
| --- | --- |
| `A`, `D` | Walk when grounded, air control when airborne, tangential momentum when hooked |
| Jump action / `Space` | Jump when grounded or within configured grace time |
| `W`, `S` | Shorten or lengthen rope while hooked |
| Left mouse | Throw selected item toward mouse cursor |
| Right mouse press | Launch hook toward mouse cursor |
| Right mouse release | Detach hook |
| `1` | Select small bomb |
| `2` | Select large bomb |
| `3` | Select flag |
| `Escape` | Pause or close the current modal |

All input is represented by named Godot input actions; gameplay code does not poll
literal keys.

### Movement targets

- Responsive acceleration and braking on the ground.
- Coyote time and jump buffering are configurable and enabled by default.
- Air control preserves momentum while allowing useful correction.
- The player cannot swim. Water applies gravity and suffocation pressure.
- The hook attaches only to hookable solid terrain within range.
- Rope length is constrained between configured minimum and maximum values.
- While attached, radial distance is constrained and `A/D` adds tangential force.
- The player detaches by releasing right mouse, losing the anchor, or dying.

### Camera

- The camera follows horizontally with configurable smoothing and map clamping.
- Vertically, it moves downward only during a run.
- The target dead-zone keeps the player near the top third of the viewport so the
  route below is visible.
- Camera shake never changes logical aiming or collision.

### Death

The player dies from:

- Touching lava.
- Remaining submerged in water until the oxygen timer expires.
- Remaining enclosed by sand until the burial timer expires.
- Entering any bomb's lethal inner blast radius.
- Leaving the valid world bounds.

Death cancels pending score submission, displays the cause briefly, and offers a
fast restart. The current depth is never saved.

## 6. Items

Every run starts with 10 small bombs, 2 large bombs, and 1 flag. Inventory cannot
be replenished in the jam release.

### Shared throwing rules

- Aim uses the mouse direction from the player's throw origin.
- Throw strength, gravity, collision mask, fuse, bounce, and impact behavior are
  definition data, not hard-coded item checks.
- The throw preview is optional polish; when present it must use the same trajectory
  service as the projectile.
- An item is consumed when successfully spawned.

### Bombs

- Small bomb nominal horizontal throw distance: about 5 hexes.
- Large bomb nominal horizontal throw distance: about 2 hexes.
- Both fall under gravity and may bounce according to configuration.
- Lava triggers immediate detonation.
- Water reduces effective blast propagation through each water cell.
- Blast propagation is evaluated on the hex grid, with separate configurable
  terrain and lethal-player radii.
- Each affected cell asks its terrain reaction how to respond. Default sequence:
  stone to dirt, dirt to sand, sand to air.
- Bomb blasts may trigger other bombs.
- A bomb kills its owner if the player is inside its lethal radius.

Exact fuse, radii, impulses, and water attenuation values live in tuning resources
and are validated through playtesting rather than fixed by this document.

### Flag

- The flag is thrown using projectile physics and never bounces.
- Water neither collides with nor destroys it.
- Lava destroys it and cancels the run.
- It sticks at the first valid solid landing contact and uses that contact depth as
  the score.
- Once thrown, it cannot be recovered or replaced.
- A valid landing pauses simulation before showing name entry.

## 7. Scoring and Leaderboard

- Score is integer depth in hex rows; greater is better.
- Only a valid planted flag creates a score.
- Local storage records last player name and personal best depth.
- The personal best appears in-world as a dashed horizontal line and HUD label.
- The global best appears as a distinct line/label when available.
- Main menu copy is `Earth owned by: {top_player_name}`; use `Nobody yet` when the
  board is empty and a neutral offline message when unavailable.
- SimpleBoards submission contains display name, depth score, and compact metadata
  including game version and map seed.
- The client API key is considered public. Jam leaderboard moderation, not strong
  anti-cheat, is the security model.
- Failed submissions are shown clearly and retained locally for a retry during the
  same session. Local personal best updates immediately.

## 8. User Interface

### Main menu

- Animated generated cave background without active hazards near the UI.
- Title: `CLAIM EARTH`.
- Top ownership line.
- `Start` and `Leaderboard` buttons.
- Compact controls panel available before starting.

### Gameplay HUD

- Selected item and remaining quantities.
- Current player depth.
- Oxygen or burial warning only while relevant.
- Hook state and rope-length feedback.
- Personal/global best direction or line labels.
- Short contextual prompts for first-run controls.

### Name entry

- Appears only after a valid flag landing.
- Field is prefilled with the last-used name and focused automatically.
- Trim whitespace; require 1-20 visible characters; replace unsupported control
  characters; preserve international player names.
- Confirming cannot create duplicate submissions from repeated input.

### Leaderboard

- Ranked rows show position, player name, and depth.
- Display loading, empty, failure, and retry states.
- Escape/back returns to the previous menu.

## 9. Art and Audio

- Assets are SVG/vector graphics or procedural textures. Do not use diffusion-model
  generated assets.
- Use thick, slightly irregular outlines, broad shapes, limited shading, and high
  contrast between hazards and safe terrain.
- Terrain interiors use procedural noise; solid-to-air boundaries receive a marked
  outline generated from neighboring cell occupancy.
- Terrain colors remain distinguishable under common color-vision deficiencies;
  water and lava also use different motion, highlights, and silhouettes.
- Character animation covers idle, run, jump/fall, throw, hook launch, swing,
  suffocation, burial, and death.
- Prioritize sound for throw, fuse, explosion size, hook attach/detach, fluid flow,
  stone creation, danger warnings, flag plant, death, and score confirmation.

## 10. Acceptance Criteria

- A player can complete the full menu-to-run-to-valid-score-to-restart loop in a
  Godot 4.6 web export on current Chromium and Firefox desktop browsers.
- The same seed creates the same initial map.
- All listed terrain interactions, items, deaths, controls, and score rules work.
- Gameplay targets 60 FPS; terrain state visibly commits at least every 0.5 seconds
  without blocking input or rendering.
- No terrain or item behavior is selected through central type branches.
- Automated tests cover deterministic domain rules; manual QA is limited primarily
  to feel, balance, clarity, and browser-specific presentation.

