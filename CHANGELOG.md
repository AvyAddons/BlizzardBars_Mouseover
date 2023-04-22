# BlizzardBars_Mouseover Change Log
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features are not yet available in the official tagged builds.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

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

