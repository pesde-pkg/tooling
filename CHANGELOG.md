# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-09-22
This release focuses on updating to newer verions of pesde and Lune, which incur breaking changes for **all** binaries. Future changes regarding
breaking toolchainlib releases will be versioned as `+toolchainlib.<rev>` versions, where `<rev>` denotes an ordinal number signifying the count
of the release. 

Since the wrapper binary packages are versioned to correspond to their upstream counterparts, we cannot properly follow semver
and breaking versions of toolchainlib may have newer runtime requirements that can cause breakage. As a result, it is always a good practice to
commit your `pesde.lock` lockfiles in order to prevent an auto-update of a tool to a newer version without your knowledge. To migrate, update the
engines requirement for your project by updating `pesde.toml` as such and run `pesde install` after:

```toml
[engines]
lune = "^0.10.2"
pesde = "^0.7.0"
```

It may also be necessary to update any scripts of your own that depend on Lune. Take a look at the [Lune CHANGELOG](https://github.com/lune-org/lune/blob/8e09fd4/CHANGELOG.md#0100---july-15th-2025) for a list of their breaking changes with v0.10.0.

### Added
- New internal scripts to autogenerate badges table on README for convenience
- Contributing docs on README
- Support for overriding arguments passed to tools by specifying an `args` argument
- CI workflow for automatically updating and publishing new versions of tools ([#20](https://github.com/pesde-pkg/tooling/pull/20))
- Support for Lune v0.10.x and the new Luau require-by-string semantics ([#28](https://github.com/pesde-pkg/tooling/pull/28))
- Special case of stripping out build metadata in the form of `toolchainlib.rev` from version in package manifest for convenience wrapper
### Changed
- Updated dependencies
- Bumped minimum Lune and pesde requirements to `^v0.10.2` and `^0.7.0` respectively
- Update reference to `luau-lsp` on README to `luau_lsp` package ([#32](https://github.com/pesde-pkg/tooling/pull/32))

## [0.1.15] - 2025-05-13
### Added
- Includes the following new tools:
  - [`pesde/blink@0.17.1`](https://pesde.dev/packages/pesde/blink/0.17.1/any)
  - [`pesde/blink@0.17.2`](https://pesde.dev/packages/pesde/blink/0.17.2/any)
  - [`pesde/luau_lsp@1.45.0`](https://pesde.dev/packages/pesde/luau_lsp/1.45.0/any)
- Add support for multi-arch binaries, currently only MacOS
- Respect the PESDE_HOME environmental variable

### Fixed
- Fix support for MacOS binaries
- Fix installations forcing interactive mode

## [0.1.14] - 2025-04-29
### Added
- Includes the following new tools:
  - [`pesde/argon@2.0.25`](https://pesde.dev/packages/pesde/argon/2.0.25/any)
  - [`pesde/luau_lsp@1.44.0`](https://pesde.dev/packages/pesde/luau_lsp/1.44.0/any)
  - [`pesde/luau_lsp@1.44.1`](https://pesde.dev/packages/pesde/luau_lsp/1.44.1/any)
  - [`pesde/rojo@7.5.0`](https://pesde.dev/packages/pesde/rojo/7.5.0/any)
  - [`pesde/rojo@7.5.1`](https://pesde.dev/packages/pesde/rojo/7.5.1/any)
  - [`pesde/asphalt@1.0.0-pre.6`](https://pesde.dev/packages/pesde/asphalt/1.0.0-pre.6/any)
  - [`pesde/asphalt@1.0.0-pre.7`](https://pesde.dev/packages/pesde/asphalt/1.0.0-pre.7/any)
  - [`pesde/asphalt@1.0.0-pre.8`](https://pesde.dev/packages/pesde/asphalt/1.0.0-pre.8/any)
### Changed
- Locked Lune to 0.8.x versions only to prevent breakage with Lune 0.9.0
- Synced package READMEs for `asphalt`

## [0.1.13] - 2025-04-21
### Added
- Added support for inferring non-interactivity status from process context ([#8](https://github.com/pesde-pkg/tooling/pull/8))
- Includes the following new tools:
  - [`pesde/zap@0.6.20`](https://pesde.dev/packages/pesde/zap/0.6.20/any)
  - [`pesde/luau_lsp@1.43.0`](https://pesde.dev/packages/pesde/luau_lsp/1.43.0/any)
### Changed
- Synced package READMEs to upstream for `asphalt` and `stylua`

## [0.1.12] - 2025-02-12
### Added
- Includes the following new tools:
  - [`pesde/argon@2.0.23`](https://pesde.dev/packages/pesde/argon/2.0.23/any)
  - [`pesde/asphalt@0.9.0`](https://pesde.dev/packages/pesde/asphalt/0.9.0/any)
  - [`pesde/asphalt@0.9.1`](https://pesde.dev/packages/pesde/asphalt/0.9.1/any)
  - [`pesde/luau_lsp@1.39.0`](https://pesde.dev/packages/pesde/luau_lsp/1.39.0/any)
  - [`pesde/luau_lsp@1.39.1`](https://pesde.dev/packages/pesde/luau_lsp/1.39.1/any)
  - [`pesde/luau_lsp@1.39.2`](https://pesde.dev/packages/pesde/luau_lsp/1.39.2/any)
  - [`pesde/blink@0.15.3`](https://pesde.dev/packages/pesde/blink/0.15.3/any)
  - [`pesde/blink@0.15.4`](https://pesde.dev/packages/pesde/blink/0.15.4/any)
  - [`pesde/zap@0.6.18`](https://pesde.dev/packages/pesde/zap/0.6.18/any)
### Fixed
- Fixed faulty calculation of lock expiration timestamp due to bad assumption about `os.time` units
- Write progress bar cleanup ANSI sequences to stderr instead to stdout to avoid managling command output
- Fix TOCTOU race condition by using an atomic operation for acquiring the installation lock
### Changed
- Migrated internal codebase to pesde v0.6.0
- Updated dependencies:
    - `dirs` to v0.3.0
    - `pathfs` to v0.3.0

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
  - [`pesde/luau_lsp@1.38.0`](https://pesde.dev/packages/pesde/luau_lsp/1.38.0/any)
  - [`pesde/luau_lsp@1.38.1`](https://pesde.dev/packages/pesde/luau_lsp/1.38.1/any)
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
  - [`pesde/luau_lsp@1.35.0`](https://pesde.dev/packages/pesde/luau_lsp/1.35.0/any)

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
[0.1.12]: https://pesde.dev/packages/pesde/toolchainlib/0.1.12/any
[0.1.13]: https://pesde.dev/packages/pesde/toolchainlib/0.1.13/any
[0.1.14]: https://pesde.dev/packages/pesde/toolchainlib/0.1.14/any
[0.1.15]: https://pesde.dev/packages/pesde/toolchainlib/0.1.15/any
[0.2.0]: https://pesde.dev/packages/pesde/toolchainlib/0.2.0/any
