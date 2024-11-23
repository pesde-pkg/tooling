local stdio = require("@lune/stdio")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local core = require("./lune_packages/core")
local Semver = require("./luau_packages/semver")
local Option = require("./lune_packages/option")
type Option<T> = Option.Option<T>

-- Use _G.PESDE_ROOT to get the install directory, then decode the
-- pesde manifest to get the version of the tool dynamically
local PLATFORM_SEP = if process.platform == "windows" then "\\" else "/"
local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local manifestContents = fs.readFile(`{_G.PESDE_ROOT}{PLATFORM_SEP}pesde.toml`)

-- TODO: Create a pesde manifest type in binlib, and use that here
local ok, manifest = pcall(serde.decode, "toml", manifestContents)
if not ok then
	stdio.ewrite(`{ERROR_PREFIX} Failed to decode bundled manifest. This is probably a bug.\n\n{manifest}`)
	process.exit(1)
end

local ok, err = pcall(
	core.installTool,
	{
		alias = Option.None,
		repo = "lune-org/lune",
		version = Option.Some(Semver.parse(manifest.version):unwrap()) :: Option<Semver.SemverImpl>,
	} :: core.ToolId
)

if not ok then
	stdio.ewrite(`{ERROR_PREFIX} Failed to install {manifest.name}@{manifest.version}`)
	stdio.ewrite(`	- {err}`)
end
