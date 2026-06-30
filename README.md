# Battle Royale Offline

An offline Battle Royale mobile game for Android built with Godot 4.6 and GDScript. Play solo against AI bots with full match mechanics — no internet required.

## Features

- **50+ AI bots** with FSM-based decision making (Easy/Medium/Hard difficulty)
- **Shrinking zone** with 5 phases, configurable speed, storm damage
- **5 weapons** across categories (AR, Shotgun, SMG, Sniper, Pistol) with rarity tiers
- **Inventory system** with 5 weapon slots, consumables (bandage, medkit, shield potion)
- **3 characters** (Blitz, Titan, Phantom) with male/female variants
- **Full match lifecycle** — lobby → drop → fight → victory/defeat
- **Career stats** — matches played, wins, kills, win rate (saved locally)
- **Settings** — controls, graphics quality, audio volume
- **Adaptive quality** — auto-reduces graphics when memory is low
- **Plug-and-play assets** — drop .glb models, .ogg audio, .png textures into folders

## Requirements

- [Godot Engine 4.6+](https://godotengine.org/download)
- No additional plugins required

## Running the Game

1. Open `project.godot` in Godot 4.6+
2. Press **F5** to run
3. Click **PLAY** → configure match settings → **Start Match**
4. Use **WASD** to move, **Spacebar/Left Click** to shoot

## Controls (PC Testing)

| Key | Action |
|-----|--------|
| W/A/S/D or Arrow Keys | Move |
| Spacebar or Left Mouse | Shoot nearest enemy |
| Mouse (future) | Aim direction |

On mobile, the game uses touch controls (virtual joystick + buttons).

## Project Structure

```
├── assets/              # Drop art assets here (see ASSET_NAMING.md)
│   ├── characters/      # .glb character models
│   ├── weapons/         # .glb weapon models
│   ├── animations/      # Animation files
│   ├── audio/           # Music, SFX, UI sounds (.ogg)
│   ├── textures/        # Terrain and UI textures (.png)
│   └── vfx/            # Particle effect scenes (.tscn)
├── data/                # Game configuration (JSON)
│   ├── characters.json
│   ├── consumables.json
│   ├── weapons.json
│   └── zone_phases.json
├── scenes/              # Godot scene files (.tscn)
├── scripts/             # GDScript source files
├── tests/               # Property and unit tests (requires GUT addon)
├── ASSET_NAMING.md      # Expected filenames for plug-and-play assets
├── FREE_ASSETS_GUIDE.md # Where to download free assets
└── project.godot        # Godot project file
```

## Adding Art Assets

The game runs with procedural placeholders (colored shapes). To add real graphics:

1. See `ASSET_NAMING.md` for exact filenames expected
2. See `FREE_ASSETS_GUIDE.md` for where to download free assets
3. Drop files into the `assets/` subfolders
4. Run the game — assets load automatically, no code changes needed

## Game Architecture

| System | Script | Responsibility |
|--------|--------|---------------|
| Scene Manager | `scene_manager.gd` | Scene transitions, persistence |
| Asset Loader | `asset_loader.gd` | Plug-and-play asset loading with fallback |
| Game Orchestrator | `game_orchestrator.gd` | Wires all systems, runs match loop |
| Match Controller | `match_controller.gd` | Match state, eliminations, victory |
| Bot AI Manager | `bot_ai_manager.gd` | Bot spawning, FSM, combat |
| Zone Manager | `zone_manager.gd` | Shrinking zone, storm damage |
| Weapon System | `weapon_system.gd` | Damage calculation, rarity modifiers |
| Inventory System | `inventory_system.gd` | Weapons, consumables, healing |
| Loot Manager | `loot_manager.gd` | Loot spawning, rarity distribution |
| HUD Manager | `hud_manager.gd` | Health, ammo, kill feed, compass |
| Audio Manager | `audio_manager.gd` | Music, SFX, spatial audio |
| Input Controller | `input_controller.gd` | Touch joystick, buttons, layout |
| Render Manager | `render_manager.gd` | Adaptive quality, memory monitoring |
| Progress Store | `progress_store.gd` | JSON-based local persistence |
| Auth Manager | `auth_manager.gd` | Guest/authenticated user management |

## Running Tests

Tests require the [GUT addon](https://github.com/bitwes/Gut):

1. Download GUT from Godot's AssetLib (search "Gut")
2. Enable the plugin in Project → Project Settings → Plugins
3. Run tests from the GUT panel

## Exporting to Android

1. Install Android SDK and set path in Editor → Editor Settings → Export → Android
2. Download Godot export templates (Editor → Manage Export Templates)
3. Go to Project → Export → Add Android preset
4. Configure signing keys
5. Click Export Project

See: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## License

This project's code is available for personal use. Art assets from third-party
sources have their own licenses — see `FREE_ASSETS_GUIDE.md` for details.
