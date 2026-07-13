# New features

## perks
breath underwater:
+ +10s breath time

lava resistance:
+ +1s touching lava delay

sulfur resistance:
+ immune to sulfur_dioxide poison
+ breath in sulfur_dioxide
+ +2s touching sulfuric_acid delay

hard skin:
+ increase impact velocity thresholds, so high impact knock out instead of killing and medium impact are ignored,
+ reduce explosion killing blast radius by 1
- player slide
- remove jelly perk

jelly:
+ remove all fall damage and knock out effects
+ player float in liquids
- player bounce
- player is thrown away by explosions (kill radius unchanged)
- remove hard skin perk

looter:
+ future item/perks picks offer 3 choices instead of 2
+ increase chest glow to 160
+ all chests indestructible

acrobat:
+ double jump
+ +50% player rope length

vaporizer:
+ generate 50% less sand on explosion
+ increase sand and liquid vaporized radius by 1 in all explosions

cave dweller:
+ shift light rendering ranges by 25 (dark vision)
+ 50% chance not to consume shovel and pickaxe when used

small boom:
+ small_bombs blast radius +1,
+ 50% chance not to consume small_bombs when used
+ (killing radius not changed)
- small_bombs generate sulfur_dioxide

large boom:
+ large_bombs blast radius +2
+ large_bombs vaporize radius +1
+ 33% chance not to consume large_bombs when used
- large_bombs killing blast radius + 1
- large_bombs generate sulfur_dioxide

relentless:
+ the flag ignore lava and acid
+ the flag is dropped on death, ensure a scored run

sand worm:
+ sand colision behave like fluid to the player
+ immune to suffocation (burried in sand)
+ breath in sand

## new items
* pickaxe: turn stone to dirt and dirt to sand, durability is a float, partial blocks consume a partial charge, 1 block range in mouse direction
* shovel: turn sand to air, durability is a float, partial blocks consume a partial charge, 1 block range in mouse direction
* flare: throw a flare like a bomb, illuminating, 10s lifespan
* fluid bottle: throw a bottle, on impact, turn the closest 3 air hexagons into the bottle fluid type, break on lava

## Mobile game export
### controls
- left stick: move
- right stick : throw/use item
- right "ring button": hook, throw on press, hold, release.

## map
### chests
- fall vertically to the ground, no rotation, no sliding
- explode like a small_bombs (separate config) if in the killing blast radius of an explosion
- can't be destroyed by water or lava
- new generation chest pass:

* item chest: choose 2 options: 5 small_bombs, 2 large_bombs, 100 shovel, 20 pickaxe, 10 flare, 3 water bottle, 3 acid bottle
* perks chest: choose 2 options between any remaining perks

### explosive barrel
- physic enabled object
- explode like a large_bombs (separate config) when touched by lava, sulfuric_acid or in an explosion blast radius,
- the player can push barrels
- the player can attach his hook to barrels and pull them.

### Sulfur block
yellow block
- turn water in contact into sulfuric_acid. consumed in a 1-5 ratio (1 sulfur hex = 5 water hex converted to sulfuric_acid)
- in contact with lava, burn blue and produce sulfur_dioxide in a 1-15 hex ratio (so 1 sulfur hex produce 15 sulfur_dioxide at 1 bar or 3 hex at 5 bar ). burn pause if there is no air and all sulfur_dioxide in a 2 hex radius are full.
- it takes 10 seconds to burn and 20 seconds to dissolve
- sulfur in a blast explosions turn into sulfur_dioxide instantly, filling the 3 nearest air blocks at 5 bar (or completing existing sulfur_dioxide blocks)

### sulfuric_acid
- new liquid type, yellow-green
- acid player hazard (see hazard section)
- consume sand underneath (down and side-down) 1-2 ratio (1 sulfuric_acid hex converted back to water = 2 sand bloc vaporized)
- sulfuric_acid sink under clear water, sulfuric_acid don't mix with water
- destroy flag

### sulfur_dioxide
- first gas type, yellow-green
- poison player hazard
- 51/255 is a unit of filled hexagon (1 bar = 51/255) above that value, it is overpressure.
- fall in air blocks, displaced by everything else, simulated like a liquid with no viscosity
- overpressurized sulfur_dioxide expands up
- consumed to turn water in contact into sulfuric_acid in 3-1 ratio (3 unit sulfur_dioxide = 1 sulfuric_acid)
- explosions don't destroy sulfur_dioxide, but push the pressure away, creating a ring of high pressure at the edge of the explosion

### uranium blocks
green glowing block
source of radiation, level = 255
diffuse like light with the same target: max_radiation_level = highest_neigbhour * current_hexagon_diffusion_coefficient. but the transfer is slow, like fluid viscosity.
if the current value is above target, the radiation level reduce slowly, with a 10% chance to randomly decrease each tick
tech note: diffusion logic for light and radiation should be implemented in a generic way. and both resolved together in a single pass
radiation level rendered in the 4th texture slot. add a green shade to the blocks with intensity proportionnal to the radiation level


note: all values should be configurable in editor

## Sound design

music

## Juice

screenshake on bomb
rework bomb vfx
hook rope texture  + hook end

