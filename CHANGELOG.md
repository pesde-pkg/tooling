# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.6] - 2024-12-25
### Added
- Includes the following new tools:
  - [`pesde/darklua@0.15.0`](https://pesde.dev/packages/pesde/darklua/0.15.0/any)
### Fixed
- Propagate and consume `Result` returned by `ProgressBar:nextStage` 
- Fix error while trying to migrate old tool_storage dir when the new one is already present

## [0.1.5] - 2024-12-22
### Added
- Includes the following new tools:
  - [`pesde/asphalt@0.8.2`](https://pesde.dev/packages/pesde/asphalt/0.8.2/any)
  - [`pesde/blink@0.15.0`](https://pesde.dev/packages/pesde/blink/0.15.0/any)
  - [`pesde/blink@0.15.1`](https://pesde.dev/packages/pesde/blink/0.15.1/any)
### Changed
- Make internal `ProgressBar` utility return `Result` instead of erroring

## [0.1.4] - 2024-12-16
### Fixed
- Fix old tool_storage migration not correctly occuring automatically on first run

## [0.1.3] - 2024-12-16
### Added
- :sparkles: Colorful :sparkles: progress bar for initial installation process when being consumed from binary packages that use toolchainlib with the default `__call` shorthand
- Use `GITHUB_TOKEN` environment variable for getting a GitHub authorization token, or default to the `gh auth token` command output if the `gh` CLI is present
- Make manifest accesses type-safe
- Download optimization by only downloading assets with formats we support
- Includes the following new tools:
  - [`pesde/luau_lsp@1.37.0`](https://pesde.dev/packages/pesde/luau_lsp/1.37.0/any)
  - [`pesde/stylua@2.0.2`](https://pesde.dev/packages/pesde/stylua/2.0.2/any)
  - [`pesde/zap@0.6.16`](https://pesde.dev/packages/pesde/luau_lsp/0.6.16/any)
### Changed
- Improve `Result` and `Option` typing by not overriding metatables and instead using an extension pattern
- Remove reliance on semver, now supporting non-semver tools as well
- Move tool_storage directory to `~/.pesde/bin/.tool_storage` to prevent potential package name conflicts in the future
- Update internal tooling updater script to fetch package READMEs from original repositories
### Fixes
- Fix some bugs with version matching with internal tooling updater script

## [0.1.2] - 2024-12-1
### Changed
- Reorganize types for internal `Github` class
- Support custom request payload for internal `Github` class
- Includes the following new tools:
  - [`pesde/argon@2.0.21`](https://pesde.dev/packages/pesde/argon/2.0.21/any)
  - [`pesde/luau_lsp@1.36.0`](https://pesde.dev/packages/pesde/luau_lsp/1.36.0/any)
  - [`pesde/darklua@0.14.1`](https://pesde.dev/packages/pesde/darklua/0.14.1/any)
  - [`pesde/zap@0.6.15`](https://pesde.dev/packages/pesde/zap/0.6.15/any)
### Fixed
- Removed duplicate version defaulting code
- Fixed panic for invalid binaries within artifacts returning an empty `PlatformDescriptor`

## [0.1.1] - 2024-11-30
### Added
- Updated tool_storage system to not tamper the base binary name, to prevent bad help menus in some tools (like selene), which change the executable mentioned in the help menu based on the name of the currently running path
- Supports tools which do not specify an executable bit in their published archives by manually changing the binary's mode on unix-like systems
- Includes the following new tools:
  - [`pesde/selene@0.27.1`](https://pesde.dev/packages/pesde/selene/0.27.1/any)
  - [`pesde/rojo@7.4.4`](https://pesde.dev/packages/pesde/rojo/7.4.4/any)
  - [`pesde/blink@0.14.5`](https://pesde.dev/packages/pesde/blink/0.14.15/any)
  - [`pesde/blink@0.15.0-rc.1`](https://pesde.dev/packages/pesde/blink/0.15.0-rc.1/any)
### Fixed
- Fixes a conditional fall-through where an invalid or corrupted executable would default to the Mach-O type, which was incorrect 

## [0.1.0] - 2024-11-26
### Added
- Initial library release :tada:
- Includes the following new tools:
  - [`pesde/stylua@2.0.1`](https://pesde.dev/packages/pesde/stylua/2.0.1/any)
  - [`pesde/luau-lsp@0.35.0`](https://pesde.dev/packages/pesde/luau_lsp/1.35.0/any)

[unreleased]: https://github.com/pesde-pkg/tooling/commits/HEAD
[0.1.0]: https://pesde.dev/packages/pesde/toolchainlib/0.1.0/any
[0.1.1]: https://pesde.dev/packages/pesde/toolchainlib/0.1.1/any
[0.1.2]: https://pesde.dev/packages/pesde/toolchainlib/0.1.2/any
[0.1.3]: https://pesde.dev/packages/pesde/toolchainlib/0.1.3/any
[0.1.4]: https://pesde.dev/packages/pesde/toolchainlib/0.1.4/any
[0.1.5]: https://pesde.dev/packages/pesde/toolchainlib/0.1.5/any
[0.1.6]: https://pesde.dev/packages/pesde/toolchainlib/0.1.6/any
