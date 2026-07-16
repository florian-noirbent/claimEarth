# New features

## meta
### statistics page

- number of time each object was used
- number of time each object was selected from a chest
- number of time each perk was picked
- number of time for each death type
- number of planted flag
- maximum depth reached
- victory count (flag planted in the earth lava core [relentless required!])
- number of chest opened
- number of perk geode opened
- total depth traveled (sum of all run)
- number of played games (at least depth 30)
- total in game time ()

### leaderboard
- replace name input with device id
- replace name list with depth reached histogram of all players

## perks
sulfur resistance:
+ immune to sulfur_dioxide poison
+ breath in sulfur_dioxide
+ +2s touching sulfuric_acid delay

glass canon:
+ immune to lava, acid, poison, breathing
- increase player killing blast radius by 2
- remove knockout and decrease impact velocity thresholds so previous knockout is now the deadly level (cancel out 'jelly' and 'hard skin' knockout effect reduction, return to normal)
- remove air control, -50 % rope length, increase gravity (cancel out acrobat, return to normal)

## new items
* fluid bottle: throw a bottle, on impact, turn the closest 3 air hexagons into the bottle fluid type, break on lava

## map
### chests
* item chest: choose 2 options: 5 small_bombs, 2 large_bombs, 100 shovel, 20 pickaxe, 10 flare, 3 water bottle, 3 acid bottle

### perk geode
* perks chest: choose 2 options between any remaining perks

### explosive barrel
- physic enabled object
- explode like a large_bombs (separate config) when touched by lava, sulfuric_acid or in an explosion blast radius, or with an high impact
- the player can push barrels
- the player can attach his hook to barrels and pull them.
- the barrel generate an overpressured cloud of sulfur_dioxide

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


note: all values should be configurable in editor


## Juice

- player spritesheets
- music
- screenshake on bomb
- rework bomb vfx and audio
- replace svg placeholders
- hook rope texture + hook end
