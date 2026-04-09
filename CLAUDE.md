# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BlizzardBars_Mouseover is a World of Warcraft addon that adds mouseover functionality to Blizzard's action bars, bags bar, and micro menu. It uses Lua 5.1 and the WoW API.

## Reference Documentation

- WoW API: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- UI Source Code: https://github.com/Gethe/wow-ui-source (also available locally in `.libraries/wow-ui-source`)

## Architecture

### File Structure and Load Order

Files are loaded in the order specified in `BlizzardBars_Mouseover.toc`:

1. **Main.lua** - Entry point. Defines addon tables (`bars`, `buttons`, `timers`, `fades`), constants, and lifecycle hooks (`OnInit`, `OnEnable`, `OnEvent`, `OnChatCommand`). Sets up frame/button references and event registrations.

2. **Core.lua** - Core functionality. Contains fade timer logic, secure hooks for OnEnter/OnLeave, and handlers for action bars, bags bar, and micro menu. Key functions:
   - `HookBars()` / `SecureHook()` - Hook individual action bars
   - `HookFrameContainers()` / `SecureHookFrameContainer()` - Hook bags bar
   - `HookMicroMenu()` / `SecureHookMicroMenu()` - Hook micro menu buttons
   - `FadeIn*Timer()` / `FadeOut*Timer()` - Timer-based alpha animations
   - `Skyriding()` / `Vehicle()` - State handlers for special conditions

3. **Localization.lua** - Localization strings (enUS default, ruRU translated).

4. **Config.lua** - Default settings (`addon.db`), settings UI definitions (`addon.settings`), profile management functions, and the Settings panel creation using WoW's Settings API.

5. **Environment.lua** - Event frame setup, event dispatcher, saved variables initialization (including profile migration), chat command registration, and addon lifecycle management.

### Key Data Structures

- `addon.sv` - The raw saved variables table (`BlizzardBars_Mouseover_DB`). Contains the profile system structure:
  - `addon.sv.profiles` - Table of all named profiles, each containing a full set of settings
  - `addon.sv.activeProfile` - Name of the currently active profile (default: `"Default"`)
  - `addon.sv.characterProfiles` - Per-character profile overrides, keyed by `"CharacterName-Realm"`
- `addon.db` - Points directly to the active profile sub-table (`addon.sv.profiles[activeProfile]`). All settings reads and writes go through this reference. **Do not use `addon.sv` for settings** — always use `addon.db`.
- `addon.defaults` - A snapshot of the default settings table, captured before `addon.db` is ever reassigned. Used to fill in missing keys when loading or creating profiles.
- `addon.registeredSettings` - Settings objects returned by `Settings.RegisterProxySetting`, keyed by `variableKey`. Used by `RefreshSettingsUI()` to update widgets in-place when switching profiles.
- `addon.bars` - References to action bar frames (keyed by bar name)
- `addon.buttons` - References to action buttons (keyed by bar name, then index)
- `addon.timers` - Active fade timers (keyed by bar name)
- `addon.fades` - Current alpha values during transitions (keyed by bar name)

### Profile System

Profiles allow different mouseover configurations to be saved and switched between. The system is implemented without external libraries.

**Structure in saved variables:**
```lua
BlizzardBars_Mouseover_DB = {
    profiles = {
        ["Default"] = { MainActionBar = true, ... },
        ["Raiding"]  = { MainActionBar = true, MicroButtons = false, ... },
    },
    activeProfile = "Default",
    characterProfiles = {
        ["MyTank-Silvermoon"] = "Raiding",
    },
}
```

**How `addon.db` works:** `Environment.lua` sets `addon.db = sv.profiles[activeProfile]` on load. From that point on, all existing code that reads or writes `addon.db[key]` transparently reads and writes the active profile's sub-table. Switching profiles just reassigns `addon.db` to a different sub-table.

**Character overrides:** When a character logs in, `Environment.lua` checks `sv.characterProfiles[charKey]`. If a profile is assigned, it takes precedence over `sv.activeProfile`. Selecting a profile from the dropdown in the Settings panel also assigns it to the current character (clearing the assignment for `"Default"` since that is the fallback).

**Migration:** On first load after an update, if `sv.profiles` is `nil`, `Environment.lua` moves any existing flat settings into `sv.profiles["Default"]` and rebuilds the structure. This ensures existing users do not lose their settings.

**Settings UI refresh:** Switching profiles calls `addon:RefreshSettingsUI()`, which iterates `addon.registeredSettings` and calls `setting:SetValue(val)` on each widget. This is the method on the setting object itself — it fires the internal changed event so widgets redraw without triggering our `SetValue` callback (which would write back to `db`). Do not confuse this with `Settings.SetValue(setting, val)`, which does the opposite.

### Fade System

The addon uses a timer-based fade system (`C_Timer.NewTicker`) that:
1. Hooks `OnEnter`/`OnLeave` on each bar/button
2. Starts fade-in timer on enter, fade-out timer on leave
3. Incrementally adjusts alpha using `AlphaMin`, `AlphaMax`, and computed step values
4. Cancels conflicting timers and supports post-completion callbacks

### Saved Variables and Settings Initialization

The addon uses `LoadSavedVariablesFirst: 1` in the TOC to ensure saved variables are available before any code runs. The Settings panel is initialized via `addon:InitializeConfig()` called from the `ADDON_LOADED` handler in Environment.lua - not `VARIABLES_LOADED`, which has no guaranteed firing order since Patch 3.0.2.

Environment.lua handles the full initialization sequence on `ADDON_LOADED`:
1. Initialize or migrate the saved variables structure into the profile format
2. Point `addon.db` at the active profile sub-table
3. Call `addon:InitializeConfig()` to register the Settings panel
4. On `PLAYER_LOGIN` (or immediately if already logged in), resolve any character-specific profile override

### Blizzard UI Interaction Patterns

When hooking Blizzard UI, be aware that Blizzard's `UpdateMicroButton()` methods call `Enable()` which resets alpha to 1 via `OnEnable`. The addon uses `hooksecurefunc` to re-apply alpha after these resets.

## Development

### Linting

The project uses lua-language-server via VS Code with the ketho.wow-api extension. Configuration is in `.luarc.json`. WoW API globals are defined in `diagnostics.globals`.

### Packaging and Release

Releases are automated via GitHub Actions using BigWigsMods/packager. Push a tag to trigger a release to CurseForge and Wago.

### Debug Mode

Code between `--@debug@` and `--@end-debug@` comments is stripped during packaging but active in development. The addon table is exposed as `_G["BBM"]` in debug mode.

### Chat Commands

- `/bbm` or `/bbm config` - Open settings
- `/bbm toggle` - Temporarily show all bars
- `/bbm help` - List commands

### Changelog

The changelog (`CHANGELOG.md`) follows [Keep a Changelog](http://keepachangelog.com/) format. Write entries for end-users with no coding knowledge - avoid technical jargon like event names, API functions, or internal implementation details.
