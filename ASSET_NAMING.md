# Asset Naming Convention

## Characters
Path: `res://assets/characters/`
Format: `{character_id}_{variant}.glb`

Expected files:
- blitz_male.glb
- blitz_female.glb
- titan_male.glb
- titan_female.glb
- phantom_male.glb
- phantom_female.glb

## Weapons
Path: `res://assets/weapons/`
Format: `{weapon_name}.glb`

Expected files:
- volt_repeater.glb (AR)
- boomstick.glb (Shotgun)
- buzzer.glb (SMG)
- longshot.glb (Sniper)
- sideswipe.glb (Pistol)

## Music
Path: `res://assets/audio/music/`
Format: `{track_name}.ogg`

Expected files:
- lobby.ogg
- drop_phase.ogg
- victory.ogg

## Sound Effects
Path: `res://assets/audio/sfx/`
Format: `{sound_name}.ogg` or `.wav`

Expected files:
- gunshot.ogg (or gunshot_ar.ogg, gunshot_shotgun.ogg, etc.)
- footstep.ogg (or footstep_01.ogg, footstep_02.ogg, etc.)
- reload.ogg
- explosion.ogg
- item_pickup.ogg
- elimination.ogg
- zone_warning.ogg
- storm_ambient.ogg

## UI Sounds
Path: `res://assets/audio/ui/`
Format: `{sound_name}.ogg`

Expected files:
- button_click.ogg
- menu_navigate.ogg

## Terrain Textures
Path: `res://assets/textures/terrain/`
Format: `{terrain_type}.png`

Expected files:
- grass.png
- concrete.png
- forest_floor.png
- rock.png

## UI Textures
Path: `res://assets/textures/ui/`
Format: `{element_name}.png`

Expected files:
- health_bar.png
- shield_bar.png
- minimap_bg.png
- crosshair.png

## VFX
Path: `res://assets/vfx/`
Format: `{effect_name}.tscn`

Expected files:
- muzzle_flash.tscn
- bullet_trail.tscn
- hit_effect.tscn
- zone_wall.tscn

## Notes
- All filenames must be lowercase
- The game runs perfectly with ZERO asset files (uses colored shapes as placeholders)
- Assets are loaded on-demand and cached
- Dropping a file in the correct folder makes it appear on next game launch
- No code changes needed to add assets
