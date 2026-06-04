# Art Asset Setup Guide — Battle Royale Offline

This guide explains how to add 3D models, animations, audio, and VFX to the game.
The code is already wired to use placeholder shapes — replacing them with real assets
is a drop-in process.

---

## Directory Structure

Place assets in these folders:

```
res://assets/
├── characters/
│   ├── blitz_male.glb        (3D model)
│   ├── blitz_female.glb
│   ├── titan_male.glb
│   ├── titan_female.glb
│   ├── phantom_male.glb
│   └── phantom_female.glb
├── weapons/
│   ├── volt_repeater.glb     (AR)
│   ├── boomstick.glb         (Shotgun)
│   ├── buzzer.glb            (SMG)
│   ├── longshot.glb          (Sniper)
│   └── sideswipe.glb         (Pistol)
├── animations/
│   ├── idle.tres
│   ├── run.tres
│   ├── shoot.tres
│   ├── jump.tres
│   ├── crouch.tres
│   ├── reload.tres
│   └── death.tres
├── audio/
│   ├── music/
│   │   ├── lobby.ogg
│   │   ├── drop_phase.ogg
│   │   └── victory.ogg
│   ├── sfx/
│   │   ├── gunshot_ar.ogg
│   │   ├── gunshot_shotgun.ogg
│   │   ├── gunshot_smg.ogg
│   │   ├── gunshot_sniper.ogg
│   │   ├── gunshot_pistol.ogg
│   │   ├── footstep_01.ogg
│   │   ├── footstep_02.ogg
│   │   ├── footstep_03.ogg
│   │   ├── reload.ogg
│   │   ├── item_pickup.ogg
│   │   ├── elimination.ogg
│   │   ├── zone_warning.ogg
│   │   ├── storm_ambient.ogg
│   │   └── explosion.ogg
│   └── ui/
│       ├── button_click.ogg
│       └── menu_navigate.ogg
├── textures/
│   ├── terrain/
│   │   ├── grass.png
│   │   ├── concrete.png
│   │   ├── dirt.png
│   │   └── rock.png
│   └── ui/
│       ├── health_bar.png
│       ├── shield_bar.png
│       ├── minimap_bg.png
│       └── crosshair.png
└── vfx/
    ├── muzzle_flash.tscn
    ├── bullet_trail.tscn
    ├── hit_effect.tscn
    └── zone_wall.tscn
```

---

## Step-by-Step: Adding Character Models

### 1. Get Models

**Free sources:**
- [Kenney.nl](https://kenney.nl/assets?q=3d+character) — Free blocky characters
- [Mixamo](https://www.mixamo.com/) — Free character animations (need a model to apply to)
- [Sketchfab](https://sketchfab.com/search?type=models&licenses=322a749bcfa841b29dff1571c9b85ce8) — Free CC0 models
- [itch.io](https://itch.io/game-assets/tag-3d/tag-character) — Many free/cheap packs
- [Quaternius](https://quaternius.com/) — Free low-poly characters and props

**Paid sources:**
- Unity Asset Store (export as .fbx/.glb from Unity)
- [CGTrader](https://www.cgtrader.com/) 
- [TurboSquid](https://www.turbosquid.com/)

### 2. File Format

Godot supports:
- `.glb` (recommended — binary glTF, smallest file size)
- `.gltf` (text glTF + separate .bin)
- `.fbx` (widely available)
- `.blend` (if Blender is installed on your machine)

### 3. Model Requirements

For this game, each character model should have:
- Humanoid skeleton (for animations)
- About 1.6m tall in the model's coordinate system
- Facing -Z direction (Godot's forward)
- Origin at the feet
- Under 10,000 polygons for mobile performance

### 4. Import Into Godot

1. Copy `.glb` files to `res://assets/characters/`
2. Godot auto-imports them (you'll see them in the FileSystem panel)
3. Double-click to preview in the editor

### 5. Wire Into the Game

Edit `scripts/character_selector.gd` and `scripts/main_menu.gd` — find the
`_load_character_model()` function and replace the capsule mesh code:

```gdscript
# Replace this:
var mesh_instance := MeshInstance3D.new()
var capsule_mesh := CapsuleMesh.new()
...

# With this:
var model_path := "res://assets/characters/%s_%s.glb" % [
    character_id.to_lower(), variant.to_lower()
]
var scene := load(model_path) as PackedScene
if scene:
    var model := scene.instantiate()
    preview_model_root.add_child(model)
```

---

## Step-by-Step: Adding Audio

### 1. File Format
- `.ogg` (OGG Vorbis) — best for music and long sounds
- `.wav` — best for short sound effects (no compression delay)
- `.mp3` — also supported

### 2. Free Audio Sources
- [Freesound.org](https://freesound.org/) — Huge library of free CC sounds
- [Kenney.nl](https://kenney.nl/assets?q=audio) — Free game audio packs
- [OpenGameArt.org](https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=13) — Free game music and SFX
- [Pixabay](https://pixabay.com/sound-effects/) — Free sound effects

### 3. Wire Into the Game

The `AudioManager` class is already set up with methods like `play_gunshot()`,
`play_music()`, etc. To make them actually play audio:

Edit `scripts/audio_manager.gd` and change the stub methods to load and play
actual AudioStreams. Example for `play_music`:

```gdscript
# Add at the top of the class:
var _music_player: AudioStreamPlayer = null

# In play_music():
func play_music(track: MusicTrack) -> float:
    if _music_player == null:
        _music_player = AudioStreamPlayer.new()
        # You need to add it to the scene tree - 
        # this requires AudioManager to extend Node instead of RefCounted
    
    var track_path := "res://assets/audio/music/%s.ogg" % _get_track_name(track)
    var stream := load(track_path) as AudioStream
    if stream:
        _music_player.stream = stream
        _music_player.volume_db = linear_to_db(music_volume / 100.0)
        _music_player.play()
    return music_volume / 100.0
```

---

## Step-by-Step: Adding Map Textures

### 1. Texture Requirements
- PNG or JPG format
- Power-of-two sizes recommended (512x512, 1024x1024)
- Seamless/tileable for terrain

### 2. Wire Into the Game

In `scripts/game_map.gd`, find `_create_terrain_region()` and replace the
solid color material with a textured one:

```gdscript
# Replace:
var material := StandardMaterial3D.new()
material.albedo_color = get_terrain_color(region.terrain_type)

# With:
var material := StandardMaterial3D.new()
var texture_path := "res://assets/textures/terrain/%s.png" % _get_terrain_texture_name(region.terrain_type)
var texture := load(texture_path) as Texture2D
if texture:
    material.albedo_texture = texture
    material.uv1_scale = Vector3(10, 10, 10)  # Tile the texture
else:
    material.albedo_color = get_terrain_color(region.terrain_type)
```

---

## Step-by-Step: Adding Weapon Models

Same as characters — place `.glb` files in `res://assets/weapons/` and
load them when the player picks up a weapon. The weapon would be attached
to the character's hand bone.

---

## Step-by-Step: Adding VFX

VFX in Godot are typically `GPUParticles3D` nodes saved as `.tscn` scenes.

1. Create particle effects in Godot's editor (GPUParticles3D node)
2. Save as `res://assets/vfx/muzzle_flash.tscn`
3. Instantiate when needed:

```gdscript
var vfx := load("res://assets/vfx/muzzle_flash.tscn").instantiate()
add_child(vfx)
vfx.position = gun_muzzle_position
vfx.emitting = true
```

---

## Quick Start (Minimum Viable Assets)

If you want the game to look decent fast, get just these:

1. **One character model** from Kenney.nl or Quaternius (free, low-poly)
2. **Gunshot sound** from Freesound.org (search "gunshot game")
3. **Background music** from OpenGameArt.org (search "battle" or "action loop")
4. **Terrain textures** from Kenney.nl (texture packs)

That alone will make it feel much more like a real game.

---

## Notes

- All asset paths use `res://assets/...` — create the `assets/` folder first
- Godot auto-imports assets when you place files in the project folder
- Models should be under 10k polygons for mobile performance
- Audio files should be under 5MB each for mobile install size
- Total assets should stay under ~400MB to meet the 500MB install size target
