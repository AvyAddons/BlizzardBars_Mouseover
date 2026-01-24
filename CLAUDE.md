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

4. **Config.lua** - Default settings (`addon.db`), settings UI definitions (`addon.settings`), and the Settings panel creation using WoW's Settings API.

5. **Environment.lua** - Event frame setup, event dispatcher, saved variables initialization, chat command registration, and addon lifecycle management.

### Key Data Structures

- `addon.db` - Saved variables (persisted settings)
- `addon.bars` - References to action bar frames (keyed by bar name)
- `addon.buttons` - References to action buttons (keyed by bar name, then index)
- `addon.timers` - Active fade timers (keyed by bar name)
- `addon.fades` - Current alpha values during transitions (keyed by bar name)

### Fade System

The addon uses a timer-based fade system (`C_Timer.NewTicker`) that:
1. Hooks `OnEnter`/`OnLeave` on each bar/button
2. Starts fade-in timer on enter, fade-out timer on leave
3. Incrementally adjusts alpha using `AlphaMin`, `AlphaMax`, and computed step values
4. Cancels conflicting timers and supports post-completion callbacks

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
