# Free Assets Guide — Where to Get Everything

This guide lists the best free sources for all game assets, with step-by-step
instructions on how to download and drop them into this project.

---

## MY TOP RECOMMENDATION (Fastest Setup)

If you want the game looking decent in under 1 hour, get these 4 things:

1. **Characters** → Quaternius Ultimate Modular Men Pack (free, includes glTF)
2. **Textures** → OpenGameArt terrain textures (free, CC0)
3. **Audio SFX** → Pixabay sound effects (free, no attribution needed)
4. **Music** → Pixabay battle/action music (free, no attribution needed)

---

## 1. CHARACTER MODELS (3D .glb files)

### Best Free Source: Quaternius
- URL: https://quaternius.com/packs/ultimatemodularcharacters.html
- License: CC0 (completely free, no attribution needed)
- Format: FBX, OBJ, glTF (use glTF/GLB for Godot)
- What you get: Modular characters with swappable parts, already rigged

**How to use:**
1. Download the pack from the link above
2. Open the glTF folder
3. Pick 3 characters to represent Blitz, Titan, Phantom
4. Rename them: `blitz_male.glb`, `blitz_female.glb`, `titan_male.glb`, etc.
5. Drop into `res://assets/characters/`

### Alternative: Quaternius Universal Base Characters
- URL: https://quaternius.com/packs/universalbasecharacters.html
- Includes 6 models (3 male, 3 female) with humanoid rig
- Perfect for this game's 3 characters × 2 variants = 6 models

### Alternative: Kenney Shape Characters (2D but stylized)
- URL: https://kenney-assets.itch.io/shape-characters
- License: CC0
- These are 2D sprites, better for a 2D approach

### Alternative: Mixamo (for animations on your models)
- URL: https://www.mixamo.com/
- Free with Adobe account
- Upload any rigged character → download with animations embedded
- Export as FBX → convert to GLB using Blender or online converter

---

## 2. WEAPON MODELS (3D .glb files)

### Best Free Source: Kenney Blaster Kit
- URL: https://kenney-assets.itch.io/blaster-kit
- License: CC0
- Includes various sci-fi blasters perfect for a battle royale
- Formats include OBJ (convert to GLB with Blender or online tool)

**How to use:**
1. Download the Blaster Kit
2. Pick 5 blasters for: volt_repeater, boomstick, buzzer, longshot, sideswipe
3. Convert to .glb if needed (use https://products.aspose.app/3d/conversion/obj-to-glb)
4. Rename: `volt_repeater.glb`, `boomstick.glb`, etc.
5. Drop into `res://assets/weapons/`

### Alternative: Quaternius (has weapon packs too)
- URL: https://quaternius.com/ (browse packs)

---

## 3. CHARACTER ANIMATIONS

### Best Free Source: Mixamo
- URL: https://www.mixamo.com/
- Free with Adobe account (just sign up)
- Has 2000+ animations ready to download

**How to use:**
1. Sign up at mixamo.com with Adobe account
2. Upload one of your character .glb/.fbx files
3. Search for animations: "idle", "running", "shooting", "jump", "crouch", "death"
4. Download each as FBX with "Without Skin" option
5. Import into Blender, export as .glb
6. Drop into `res://assets/animations/`

**Animations you need:**
- idle.glb (standing still)
- run.glb (running forward)
- shoot.glb (firing weapon)
- jump.glb (jumping)
- crouch.glb (crouching)
- death.glb (falling down)

---

## 4. TERRAIN TEXTURES (PNG files)

### Best Free Source: OpenGameArt
- Grass: https://opengameart.org/content/grass-textureseamless-2d
- Terrain pack: https://opengameart.org/content/seamless-terrain-and-concrete-textures
- Ground pack: https://opengameart.org/content/36-free-ground-textures-diffuse-normals
- License: CC0 or CC-BY (check each)

### Alternative: FreePBR
- Grass: https://freepbr.com/product/grass-1-pbr-material/
- Rock: https://freepbr.com/product/rocky-rugged-terrain-pbr/
- Free for games, high quality 2048x2048 PNG

### Alternative: Kenney Texture Packs
- Various terrain textures at https://kenney.nl/assets (search "texture")
- CC0 license

**How to use:**
1. Download grass, concrete, rock, and forest floor textures
2. Rename to: `grass.png`, `concrete.png`, `rock.png`, `forest_floor.png`
3. Resize to 512x512 or 1024x1024 if they're too large
4. Drop into `res://assets/textures/terrain/`

---

## 5. AUDIO — SOUND EFFECTS (OGG/WAV files)

### Best Free Source: Pixabay Sound Effects
- URL: https://pixabay.com/sound-effects/
- License: Pixabay License (free, no attribution required, commercial use OK)
- Search for: "gunshot", "footstep", "explosion", "reload", "pickup"

### Alternative: itch.io Sound Packs
- Footsteps: https://wasd-sound.itch.io/free-integrated-footstep-sfx-bundle
- Footsteps 2: https://mayragandra.itch.io/free-footsteps-sound-effects
- General game SFX: https://hazardpay.itch.io/40-free-psx-crunchy-footsteps

### Alternative: Freesound.org
- URL: https://freesound.org/
- Huge library, filter by CC0 license
- Search: "game gunshot", "footstep concrete", "item pickup"

**How to use:**
1. Download sounds from Pixabay (they download as MP3)
2. Convert MP3 to OGG using: https://convertio.co/mp3-ogg/
3. Rename files:
   - `gunshot.ogg`
   - `footstep.ogg`
   - `reload.ogg`
   - `explosion.ogg`
   - `item_pickup.ogg`
   - `elimination.ogg`
   - `zone_warning.ogg`
   - `storm_ambient.ogg`
4. Drop into `res://assets/audio/sfx/`

---

## 6. AUDIO — MUSIC (OGG files)

### Best Free Source: Pixabay Music
- Battle/Action: https://pixabay.com/music/search/battle%20royale/
- Fighting game: https://pixabay.com/music/search/fighting%20game/
- License: Free, no attribution required

### Alternative: OpenGameArt Music
- URL: https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=12
- Filter by CC0 license for worry-free usage

**How to use:**
1. Download 3 tracks from Pixabay:
   - A calm/menu track → rename to `lobby.ogg`
   - An intense/action track → rename to `drop_phase.ogg`
   - A triumphant/victory track → rename to `victory.ogg`
2. Convert to OGG if downloaded as MP3
3. Drop into `res://assets/audio/music/`

---

## 7. UI TEXTURES (PNG files)

### Best Free Source: Kenney UI Packs
- URL: https://kenney.nl/assets (search "UI")
- License: CC0
- Includes buttons, panels, icons, sliders, bars

### Alternative: Create your own
- Use any image editor (GIMP is free: https://www.gimp.org/)
- Health bar = green rectangle 256x32 PNG
- Shield bar = blue rectangle 256x32 PNG
- Crosshair = white circle/cross on transparent background 64x64 PNG

**How to use:**
1. Download Kenney UI pack
2. Pick health bar, shield bar assets
3. Create a simple crosshair PNG (white cross, 64x64, transparent bg)
4. Rename: `health_bar.png`, `shield_bar.png`, `crosshair.png`, `minimap_bg.png`
5. Drop into `res://assets/textures/ui/`

---

## 8. VFX (Particle Effects)

VFX are Godot scene files (.tscn) — you create these IN Godot:

**How to create muzzle flash:**
1. In Godot, create a new scene with root node `GPUParticles3D`
2. Set Amount = 20, Lifetime = 0.1, One Shot = true
3. Set Process Material → emission shape = sphere, radius = 0.1
4. Set color to orange/yellow
5. Save as `res://assets/vfx/muzzle_flash.tscn`

**Or find free Godot VFX:**
- Search GitHub for "godot particles effects"
- URL: https://github.com/topics/godot-particles

---

## QUICK START CHECKLIST

Do these steps in order for fastest results:

### Step 1: Characters (10 minutes)
- [ ] Go to https://quaternius.com/packs/ultimatemodularcharacters.html
- [ ] Download the pack
- [ ] Pick 6 character .glb files
- [ ] Rename to: blitz_male.glb, blitz_female.glb, titan_male.glb, titan_female.glb, phantom_male.glb, phantom_female.glb
- [ ] Copy to `res://assets/characters/`

### Step 2: Textures (5 minutes)
- [ ] Go to https://opengameart.org/content/36-free-ground-textures-diffuse-normals
- [ ] Download the pack
- [ ] Pick grass, concrete, rock, and dirt textures
- [ ] Rename to: grass.png, concrete.png, rock.png, forest_floor.png
- [ ] Copy to `res://assets/textures/terrain/`

### Step 3: Sound Effects (10 minutes)
- [ ] Go to https://pixabay.com/sound-effects/
- [ ] Search and download: "gunshot game", "footstep", "explosion", "pickup item game"
- [ ] Convert to .ogg if needed (https://convertio.co/mp3-ogg/)
- [ ] Rename to match ASSET_NAMING.md
- [ ] Copy to `res://assets/audio/sfx/`

### Step 4: Music (5 minutes)
- [ ] Go to https://pixabay.com/music/search/battle%20royale/
- [ ] Download 3 tracks (calm, intense, victory)
- [ ] Convert to .ogg
- [ ] Rename to: lobby.ogg, drop_phase.ogg, victory.ogg
- [ ] Copy to `res://assets/audio/music/`

### Step 5: Run the game
- [ ] Press F5 in Godot
- [ ] Characters should now show real 3D models instead of capsules
- [ ] Terrain should have textures instead of flat colors
- [ ] You should hear sounds and music

---

## FILE FORMAT CONVERSION TOOLS (Free)

| Convert From | Convert To | Free Tool |
|---|---|---|
| FBX → GLB | .glb | Blender (free, https://www.blender.org/) or online: https://products.aspose.app/3d/conversion |
| OBJ → GLB | .glb | Same as above |
| MP3 → OGG | .ogg | https://convertio.co/mp3-ogg/ or Audacity (free) |
| WAV → OGG | .ogg | https://convertio.co/wav-ogg/ |
| JPG → PNG | .png | Any image editor or https://convertio.co/jpg-png/ |
| Large PNG → 512x512 | .png | https://www.iloveimg.com/resize-image |

---

## LICENSE SUMMARY

| Source | License | Attribution Needed? | Commercial Use? |
|---|---|---|---|
| Quaternius | CC0 | No | Yes |
| Kenney | CC0 | No | Yes |
| OpenGameArt (CC0) | CC0 | No | Yes |
| OpenGameArt (CC-BY) | CC-BY | Yes (credit in game) | Yes |
| Pixabay | Pixabay License | No | Yes |
| Mixamo | Adobe Terms | No | Yes (in games) |
| Freesound (CC0) | CC0 | No | Yes |

**Safest choice:** Stick to CC0 sources (Quaternius, Kenney, Pixabay) — zero legal concerns.

---

## NOTES

- All assets are optional — the game works without any of them
- You can add assets gradually (just characters first, then textures later, etc.)
- Godot auto-imports files when you copy them into the project folder
- If a .glb doesn't look right, try opening it in Blender first to check scale/orientation
- Character models should be about 1.6m tall and face -Z direction for Godot
- Audio files should be under 5MB each to keep install size reasonable
- Total assets should stay under 400MB for the 500MB mobile install target
