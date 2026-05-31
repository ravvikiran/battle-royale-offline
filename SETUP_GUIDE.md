# Battle Royale Offline — Setup & Run Guide

## What You Need

- **Godot Engine 4.2+** (free, no account required)
- Your project folder (this one)
- That's it. No Android Studio, no emulator, no SDK.

---

## Quick Clarification

**Godot is a game engine, not an Android emulator.** It runs your game project natively on your computer as a desktop application. Since the game is built with Godot's tools and scripting language (GDScript), it runs directly on Windows or Mac without any Android layer.

You **cannot** run arbitrary Android apps (.apk files) in Godot. It only runs Godot projects.

---

## Step 1: Download Godot

### Windows
1. Go to https://godotengine.org/download/windows/
2. Download **Godot Engine - Standard** (64-bit, .zip file)
3. Extract the zip anywhere (e.g., `C:\Godot\`)
4. You'll get a single file: `Godot_v4.x-stable_win64.exe`
5. No installation needed — just run the .exe

### macOS
1. Go to https://godotengine.org/download/macos/
2. Download **Godot Engine - Standard** (.zip file)
3. Extract the zip
4. Move `Godot.app` to your Applications folder
5. First launch: right-click → Open (to bypass Gatekeeper)

---

## Step 2: Open the Project

1. Launch Godot
2. On the Project Manager screen, click **Import**
3. Navigate to this project folder:
   ```
   battle-royale-offline/
   ```
4. Select the `project.godot` file
5. Click **Import & Edit**

The editor will open with your project loaded.

---

## Step 3: Run the Game

1. In the Godot editor, press **F5** (or click the Play ▶ button in the top-right)
2. The game launches in a new window on your desktop
3. The main menu appears — you can navigate with mouse clicks

### Controls in Desktop Mode
Since this is a mobile game with touch controls, here's how they map on desktop:

| Mobile Action | Desktop Equivalent |
|---|---|
| Tap | Left mouse click |
| Touch & drag (aim) | Click and drag on right side |
| Joystick (move) | Click and drag on left side |
| Buttons (shoot, reload, etc.) | Click the on-screen buttons |

---

## Step 4: Run Tests (Optional)

This project uses the GUT (Godot Unit Test) framework for testing.

### Install GUT Plugin
1. In the Godot editor, go to **AssetLib** tab (top center)
2. Search for "GUT" (Godot Unit Testing)
3. Click Download → Install
4. Enable the plugin: Project → Project Settings → Plugins → GUT → Enable

### Run Tests
1. After enabling GUT, a **GUT** panel appears at the bottom of the editor
2. Click the GUT panel
3. Set the test directories to:
   - `res://tests/unit/`
   - `res://tests/property/`
4. Click **Run All**

---

## Project Structure Overview

```
battle-royale-offline/
├── project.godot          ← Open this in Godot
├── data/                  ← Game configuration (weapons, zones, characters)
├── scripts/               ← All game logic (GDScript)
├── scenes/                ← UI layouts and game scenes
├── resources/             ← Art assets (placeholder for now)
└── tests/                 ← Unit and property-based tests
    ├── unit/
    └── property/
```

---

## Common Issues

### "Scene not found" errors on first run
This is normal if placeholder assets are missing. The game logic runs fine — visual elements just won't render until you add actual 3D models and textures.

### macOS: "App is damaged" or won't open
Right-click → Open, then click Open in the dialog. This is macOS Gatekeeper blocking unsigned apps.

### Game window is portrait (tall and narrow)
This is intentional — the game targets mobile portrait orientation (1080×1920). You can resize the window or change the display settings in Project → Project Settings → Display → Window.

---

## When You Want to Build for Android (Later)

Only when you're ready to put the game on an actual phone:

1. Install Android Studio (for the SDK and build tools)
2. In Godot: Editor → Editor Settings → Export → Android
3. Set the paths to your Android SDK and JDK
4. Project → Export → Add Android preset → Export APK

This is a one-time setup for the final build. You don't need it for development.

---

## Summary

| Task | What You Need |
|---|---|
| Develop & test the game | Godot Editor only |
| Run on your PC/Mac | Godot Editor only |
| Run tests | Godot Editor + GUT plugin |
| Build for Android phone | Godot + Android SDK (later) |
| Run Android .apk files | Not possible in Godot (use an emulator for that) |
