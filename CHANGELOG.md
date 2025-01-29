# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.11] - 2025-01-23
### Added
- Progress bars are now written to stderr to prevent issues with parsing managed tooling outputs
- It is now possible for dependents of toolchainlib to programatically disable interactive features (like progress bars) by setting `_G.interactive` to `false`.
- Includes the following new tools:
  - [`pesde/zap@0.6.17`](https://pesde.dev/packages/pesde/zap/0.6.17/any)
  - [`pesde/darklua@0.16.0`](https://pesde.dev/packages/pesde/darklua/0.16.0/any)
  - [`pesde/argon@2.0.22`](https://pesde.dev/packages/pesde/argon/2.0.22/any)
### Fixed
- Fixed attempt to clear progress bar even when not in interactive mode

## [0.1.10] - 2025-01-22
### Added
- Locking mechanism to prevent conflicting accesses of underlying tool binaries. The lock is an on-disk file which exists during the installation process, and is removed once it is complete. It is located at `~/.pesde/bin/.tool_storage/<tool_id>/<version>/LOCK` and is a JSON file of the following structure:
```jsonc
{
  "resource": "/home/usr/.pesde/bin/.tool_storage/<tool_id>/<version>/<tool>", // The path to the resource being protected, i.e., the tool binary
  "expiration": 1737480284 // The timestamp until which the lock is considered valid, which is 60s from its creation
}
```

### Fixed
- Fixed concurrent installations failing due to OS errors during resource access by using aforementioned locking mechanism
- Fixed faulty check for existence of tool installation directory 
### Changed
- Improved internal structuring for conditional progress bar rendering

## [0.1.9] - 2025-01-16
### Fixed
- Fixed a `TypeError` in internal decompression function for ZIP
- Fixed certain PE executables not being detected correctly due to incorrectly reading the DOS offset

## [0.1.8] - 2025-01-16
## Added
- Includes the following new tools:
  - [`pesde/asphalt@0.8.4`](https://pesde.dev/packages/pesde/asphalt/0.8.4/any)
  - [`pesde/selene@0.28.0`](https://pesde.dev/packages/pesde/selene/0.28.0/any)
  - [`pesde/blink@0.15.2`](https://pesde.dev/packages/pesde/blink/0.15.2/any)
### Changed
- Use [`luau-unzip`](https://github.com/0x5eal/luau-unzip) to extract archives instead of using an external program

## [0.1.7] - 2024-12-28
### Added
- Includes the following new tools:
  - [`pesde/asphalt@0.8.3`](https://pesde.dev/packages/pesde/asphalt/0.8.3/any)
  - [`pesde/luau-lsp@1.38.0`](https://pesde.dev/packages/pesde/luau_lsp/1.38.0/any)
  - [`pesde/luau-lsp@1.38.1`](https://pesde.dev/packages/pesde/luau_lsp/1.38.1/any)
### Fixed
- Conditionally handle `ProgressBar:nextStage` result, fixing an error when being consumed as a library without the use of the `__call` metamethod shorthand
- Fix error when the `gh` CLI is not installed by correctly handling it as a `Result`

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
  - [`pesde/luau-lsp@1.35.0`](https://pesde.dev/packages/pesde/luau_lsp/1.35.0/any)

[unreleased]: https://github.com/pesde-pkg/tooling/commits/HEAD
[0.1.0]: https://pesde.dev/packages/pesde/toolchainlib/0.1.0/any
[0.1.1]: https://pesde.dev/packages/pesde/toolchainlib/0.1.1/any
[0.1.2]: https://pesde.dev/packages/pesde/toolchainlib/0.1.2/any
[0.1.3]: https://pesde.dev/packages/pesde/toolchainlib/0.1.3/any
[0.1.4]: https://pesde.dev/packages/pesde/toolchainlib/0.1.4/any
[0.1.5]: https://pesde.dev/packages/pesde/toolchainlib/0.1.5/any
[0.1.6]: https://pesde.dev/packages/pesde/toolchainlib/0.1.6/any
[0.1.7]: https://pesde.dev/packages/pesde/toolchainlib/0.1.7/any
[0.1.8]: https://pesde.dev/packages/pesde/toolchainlib/0.1.8/any
[0.1.9]: https://pesde.dev/packages/pesde/toolchainlib/0.1.9/any
[0.1.10]: https://pesde.dev/packages/pesde/toolchainlib/0.1.10/any
[0.1.11]: https://pesde.dev/packages/pesde/toolchainlib/0.1.11/any

