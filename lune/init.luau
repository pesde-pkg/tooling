local core = require("./lune_packages/core")
local semver = require("./luau_packages/semver")
local Option = require("./lune_packages/option")
type Option<T> = Option.Option<T>

-- TODO: Use _G._PESDE_ROOT to get the install directory, then decode the 
-- pesde manifest to get the version of the tool dynamically
core.installTool({
	alias = Option.Some("lune"),
	repo = "lune-org/lune",
	version = Option.Some(semver.parse("0.8.9"):unwrap()) :: Option<semver.SemverImpl>,
} :: core.ToolId)
