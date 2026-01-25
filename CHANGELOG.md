# BlizzardBars_Mouseover Changelog
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features are not yet available in the official tagged builds.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased
### Added
- The Buff Frame and Debuff Frame now support mouseover (closes [#13](https://github.com/AvyAddons/BlizzardBars_Mouseover/issues/13))

### Fixed
- Fixed micro menu buttons remaining visible on login until hovered (closes [#17](https://github.com/AvyAddons/BlizzardBars_Mouseover/issues/17))

## [4.1.0] 2026-01-24
### Fixed
- Settings should now save more reliably after a UI reload
- Resolved a conflict with BetterCooldownManager that caused bars to become visible after changing zones or talent specs (closes [#18](https://github.com/AvyAddons/BlizzardBars_Mouseover/issues/18))

### Changed
- Better handling for players returning after a long break

## [4.0.2] 2026-01-24
### Fixed
- Fade Housing micro button alongside others

### Changed
- Dropped support for War Within

## [4.0.1] 2025-12-03
### Fixed
- Main Action Bar works again (closes [#15](https://github.com/AvyAddons/BlizzardBars_Mouseover/issues/15))
  Preempted the Midnight changes; they're already active in 11.2.7

## [4.0.0] 2025-11-23
### Added
- Support for Midnight Beta
- Support for `ruRU` locale (by @ZamestoTV)

### Changed
- Bump TOC to 11.2.7

## [3.0.1] 2025-10-08
### Changed
- Bump TOC to 11.2.5

## [3.0.0] 2025-10-02
### Added
- The Bags Bar and the Micro Menu now support mouseover!

### Fixed
- Internal fix for possible taints in event handler

## [2.6.2] 2025-08-06
### Changed
- Bump TOC to 11.2.0

## [2.6.1] 2025-07-19
### Changed
- Bump TOC to 11.1.7

## [2.6.0] 2025-06-28
### Added
- Add a new setting to always show the Exit Vehicle button.

## [2.5.1] 2025-04-27
### Changed
- Bump TOC to 11.1.5

## [2.5.0] 2025-02-26
### Changed
- Bump TOC to 11.1.0
- Add Category

## [2.4.5] 2025-02-06
### Removed
- Drop support for TOC 11.0.2

## [2.4.4] 2025-01-20
### Fixed
- Updated settings text to reflect when a `/reload` is required.

## [2.4.3] 2024-12-18
### Changed
- Bump TOC to 11.0.7

## [2.4.2] 2024-10-23
### Changed
- Bump TOC to 11.0.2, 11.0.5

## [2.4.1] 2024-10-14
### Fixed
- Opening flyout spells from the Spellbook no longer errors

## [2.4.0] 2024-08-14
### Fixed
- The chat commands (`/bbm` and `/bbm config`) now properly open to BBM's settings

### Changed
- Update Configuration panel to new Vertical Layout

## [2.3.0] 2024-08-05
### Improvements
- Improved Skyriding detection. Should now be faster and cause less lag (thanks WA team!)
### Fixed
- Fixed taint when clicking bars with mouseover enabled
### Changed
- Major code refactoring, now with better logical split

## [2.2.1] 2024-07-27
### Fixed
- Update deprecated API in chat command `/bbm`

## [2.2.0] 2024-07-27
### Changed
- Update deprecated APIs
- Bumped TOC to 11.0.0, 11.0.2

## [2.1.4] 2024-05-08
### Changed
- Bumped TOC to 10.2.7

## [2.1.3] 2024-04-13
### Changed
- Bumped TOC to 10.2.6

## [2.1.2] 2024-01-17
### Fixed
- Resolved a `nil` reference in macOS clients
### Changed
- Bumped TOC to 10.2.5

## [2.1.1] 2023-11-21
### Fixed
- Resolved a flickering issue with linked bars
### Changed
- Removed unused code, addon is now lighter

## [2.1.0] 2023-11-19
### Changed
- Added option to Show/Hide main bar during dragonriding.
  - Enabled by default (keeps previous behaviour)
- Updated some deprecated Blizzard APIs

## [2.0.7] 2023-11-08
### Changed
- Bumped TOC to 10.2.0

## [2.0.6] 2023-09-08
### Changed
- Bumped TOC to 10.1.7

## [2.0.5] 2023-07-15
### Changed
- Bumped TOC to 10.1.5

## [2.0.4] 2023-04-21
### Fixed
- The main bar will now recheck dragonriding conditions after changing zones

	This fixes instances where the character was dragonriding and teleports to a dungeon via LFG, for example.

## [2.0.3] 2023-03-22
### Changed
- Bumped TOC to 10.0.7

## [2.0.2] 2023-01-25
### Changed
- Bumped TOC to 10.0.5

## [2.0.1] 2022-12-13
### Fixed
- Bars will finish fading in before fading out if mouseover ends before then.

## [2.0.0] 2022-12-11
### Added
- Configuration panel (#1)
- Fade-in and fade-out for a smooth transition (#1)
- Option to link all bars

### Removed
- Chat command for pets: `/bbm pet` (now as a setting)

### Fixed
- Resolved some Dragonriding issues where the bars wouldn't show

Many thanks to @Bulbistan and @Tcheetox for their contributions in this release!

## [1.3.0] 2022-11-20
### Added
- New command to show or hide the pet bar: `/bbm pet`
- New command to toggle mouseover: `/bbm toggle`

### Fixed
- The "Exit Vehicle" button now shows properly on mouseover

### Removed
- Removed old `/togglemo` command

## [1.2.0] 2022-11-16
### Added
- The cooldown bling is now hidden
- Added command to toggle mouseover: `/togglemo`
- Bumped TOC to 10.0.2

## [1.1.0] 2022-11-07
### Added
- Dragonriding overrides for main bar
- Bar stays visible while a flyout is open

### Fixed
- Resolve nil index issue when mounting up

## [1.0.0] 2022-11-07
### Added
- Initial release :)

