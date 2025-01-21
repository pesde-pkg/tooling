--> ENTRYPOINT; The main logic is as follows:
--> * First, we fetch the artifacts
--> * We try going through the list and using pattern matching to figure out
-->   which is the artifact to download
--> * If we get no matches, we try downloading all the artifacts
--> * The artifacts are all extracted and we try detecting the platform from
-->   binary data
--> * We then install the artifact with the matching platform descriptor

local net = require("@lune/net")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local task = require("@lune/task")

local pathfs = require("../lune_packages/pathfs")
local dirs = require("../lune_packages/dirs")

local Result = require("../lune_packages/result")
local ResultExt = require("./utils/ext/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local Github = require("./github")
local PlatformDescriptor = require("./platform/descriptor")
local ProgressBar = require("./utils/progress")
local compression = require("./compression")
local eq = require("./utils/eq")
local manifest = require("./manifest")

export type ToolId = {
	alias: Option<string>,
	repo: string,
	version: Option<string>,
}

-- TODO: Remove this in a breaking change
export type GithubReleases = Github.GithubReleases

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`
local _INFO_PREFIX = `{stdio.color("green")}{stdio.style("bold")}info{stdio.color("reset")}:`
local WARN_PREFIX = `{stdio.color("yellow")}{stdio.style("bold")}warn{stdio.color("reset")}:`

local function warn(...)
	stdio.ewrite(`{WARN_PREFIX} {stdio.format(...)}\n`)
end

local function downloadAndExtractBinary(
	binaryName: string,
	targetPlatform: PlatformDescriptor.PlatformDescriptor,
	asset: {
		name: string,
		browser_download_url: string,
		size: number,
		content_type: string,
	}
): Option<buffer>
	return compression
			.detectFormat(asset.name)
			:andThen(function(format: compression.CompressionFormat)
				local contentsResp = net.request(asset.browser_download_url)
				if not contentsResp.ok then
					return error(`Failed to download asset {asset.name}: HTTP Code {contentsResp.statusCode}`)
				end

				return ResultExt.ok(
					compression.extractBinary[format](buffer.fromstring(contentsResp.body), binaryName, targetPlatform)
				)
			end) :: Option<buffer>
end

local function chmod(path: pathfs.Path, mode: number | string)
	if process.os == "windows" then
		return
	end

	local result = process.spawn(
		"chmod",
		{ if typeof(mode) == "string" then mode else string.format("%o", mode), path:toString() }
	)

	if not result.ok then
		return error(result.stderr)
	end
end

local function toolAliasOrDefault(tool: ToolId): string
	return tool.alias:unwrapOr(string.split((tool :: ToolId).repo, "/")[2])
end

local function stripLeadingVersion(version: string): string
	local stripped = string.gsub(version, "^v", "")
	return stripped
end

local LINK_INSTALL_DIR = (dirs.homeDir() or error("Couldn't get home dir :(")):join(".pesde"):join("bin")
local TOOL_STORAGE_DIR = LINK_INSTALL_DIR:join(".tool_storage")
if not pathfs.isDir(TOOL_STORAGE_DIR) then
	pathfs.writeDir(TOOL_STORAGE_DIR)
end

local OLD_TOOL_STORAGE_DIR = LINK_INSTALL_DIR:join("tool_storage")
if pathfs.isDir(OLD_TOOL_STORAGE_DIR) and not pathfs.isDir(TOOL_STORAGE_DIR) then
	-- TODO: Merge both directories into one instead of a single move
	pathfs.move(OLD_TOOL_STORAGE_DIR, TOOL_STORAGE_DIR)
end

local TOOLING_LOCK_FILE = TOOL_STORAGE_DIR:join("LOCK")

local bar = ProgressBar.new()
	:withStage("init", "Initializing")
	:withStage("fetch", "Fetching release")
	:withStage("locate", "Identifying asset")
	:withStage("download", "Downloading")
	:withStage("install", "Installing")

function runTool(tool: ToolId | pathfs.Path): number
	-- FIXME: `process.spawn` has a bug where interactive features don't
	-- forward properly
	local toolId = tool :: ToolId
	local path = if (toolId :: any).alias ~= nil
		then LINK_INSTALL_DIR:join(toolAliasOrDefault(toolId))
		else tool :: pathfs.Path

	return process.spawn(path:toString(), process.args, {
		cwd = process.cwd,
		env = process.env,
		stdio = "forward",
	}).code
end

local function makeConditionalBar()
	local function makeConditional(fn: (ProgressBar.ProgressBarImpl) -> ())
		return function(bar: ProgressBar.ProgressBarImpl)
			if _G.interactive then
				return fn(bar)
			end

			return
		end
	end

	return {
		next = makeConditional(function(bar)
			return bar:nextStage():unwrap()
		end),
		start = makeConditional(bar.start),
		stop = makeConditional(bar.stop),
	}
end

local function getGithubToken(): Option<string>
	return Option.from(process.env.GITHUB_TOKEN):orElse(function()
		return ResultExt.ok(Result.try(process.spawn, "gh", { "auth", "token" }))
			:andThen(function(child: process.SpawnResult)
				if not child.ok then
					return Option.None
				end

				-- Remove newlines and other control characters
				local token = string.gsub(child.stdout, "%s+", "")
				return Option.Some(token)
			end)
	end)
end

-- Initialize the shared global progress bar state
_G.interactive = false
local barFns

function installTool(tool: ToolId, installPath: pathfs.Path): number
	-- Attempt to read an existing lock in EAFP fashion
	local isLocked, existingInstallPath = pcall(pathfs.readFile, TOOLING_LOCK_FILE)
	if isLocked then
		-- If the lock was held and we know the same tool that we are trying to install
		-- is also being installed elsewhere, we wait for that installation attempt to
		-- finish, i.e., the lock file is removed, and then run the freshly installed tool
		if installPath:toString() == existingInstallPath then
			-- Disable the progress bar since we're not actually an installation process
			_G.interactive = false

			warn("Waiting for existing installation process for tool to exit")
			while pathfs.isFile(TOOLING_LOCK_FILE) do
				task.wait(1)
			end

			return runTool(installPath)
		end
	end

	-- Write a lock file to prevent concurrent installation attempts
	pathfs.writeFile(TOOLING_LOCK_FILE, installPath:toString())

	barFns = makeConditionalBar()
	barFns.start(bar) -- init

	local toolAlias = toolAliasOrDefault(tool)
	local client = Github.new(
		tool.repo,
		Option.Some({
			authToken = getGithubToken(),
			retries = Option.None :: Option<number>,
		}) :: Option<Github.Config>
	)

	barFns.next(bar) -- fetch
	local releases = client:queueTransactions({ "FetchReleases" })[1]:unwrap() :: GithubReleases
	local assets = tool.version:match({
		Some = function(version: string)
			for _, release in releases do
				if stripLeadingVersion(release.tag_name) == stripLeadingVersion(version) then
					return release.assets
				end
			end

			return error(`No release found for version {version}`)
		end,

		None = function()
			return releases[0].assets
		end,
	})

	barFns.next(bar) -- locate

	-- TODO: Use index type fn in solver v2
	local matchingAsset: {
		name: string,
		browser_download_url: string,
		size: number,
		content_type: string,
	}

	local currentDesc = PlatformDescriptor.currentSystem()
	local aliasPath = pathfs.Path.from(toolAlias):withExtension(if currentDesc.os == "windows" then "exe" else "")
	local aliasName = aliasPath:toString()

	for _, asset in assets do
		local desc = PlatformDescriptor.fromString(asset.name)
		local descWithArch = desc:map(function(inner: PlatformDescriptor.PlatformDescriptor)
			return inner
		end)

		if descWithArch:isOk() and eq(currentDesc, descWithArch:unwrap()) then
			matchingAsset = asset
			break
		end
	end

	barFns.next(bar) -- download

	local binaryContents: buffer
	if matchingAsset == nil then
		stdio.write("\x1b[2K\x1b[0G")
		warn("Pesde could not find a matching binary for your system")
		warn("Will now attempt to download all binaries and find a matching one")

		for _, asset in assets do
			local contents = downloadAndExtractBinary(aliasName, currentDesc, asset)
			if contents:isSome() then
				binaryContents = contents:unwrap()
				break
			end
		end
	else
		downloadAndExtractBinary(aliasName, currentDesc, matchingAsset):match({
			Some = function(contents: buffer)
				binaryContents = contents
			end,
			None = function()
				error(`No matching binary found`)
			end,
		})
	end

	barFns.next(bar) -- install

	-- Maintain multiple versions of a tool, and avoid downloading
	-- the binary for a version again if it's already there
	local toolDir = Option.from(installPath:parent()):unwrap()
	if not pathfs.isFile(toolDir) then
		pathfs.writeDir(toolDir)
	end

	pathfs.writeFile(installPath, binaryContents)

	-- IDEA: In order to eliminate fs read overhead on startup and to disallow
	-- the use of the tool binary when outside a package where it is installed,
	-- we can improve this by following what rokit does, where we symlink
	-- the tool's path to this script, and check the file that we are being
	-- invoked as, in order to figure out what tool to execute

	-- We can create "linker" scripts for each tool at ~/.pesde/bins with
	-- contents like so:
	--[[
		#!/bin/env -S lune run

		-- First off, we check whether the tool is installed in pesde.toml
		-- if we're being run as a symlink, and not a `pesde x` bin

		local pathInfo = debug.info(1, "s")
		local path = string.sub(pathInfo, 10, #pathInfo - 2))

		-- Now we can use `path` to figure out the real tool to execute
		-- ...
	]]

	barFns.stop(bar)

	-- NOTE: This is equivalent to `0o755` or `rwxr-xr-x`
	chmod(installPath, 0b10101010011)

	-- Release the installation lock
	pathfs.removeFile(TOOLING_LOCK_FILE)

	-- Finally run the tool
	return runTool(installPath)
end

type LibExports = {
	runTool: (pathfs.Path | ToolId) -> number,
	installTool: (ToolId, pathfs.Path) -> never,
}
type LibExportsImpl = typeof(setmetatable(
	{} :: LibExports,
	{ __call = function(lib: LibExportsImpl, tool: string, pesdeRoot: string?) end }
))

return setmetatable(
	{
		runTool = runTool,
		installTool = installTool,
	} :: LibExports,
	{
		__call = function(lib: LibExportsImpl, tool: string, pesdeRoot: string?): number
			_G.interactive = true

			local repo, version = string.match(tool, "([^@]+)@?(.*)")
			if repo == nil or version == nil then
				stdio.ewrite(`{ERROR_PREFIX} Invalid tool provided\n`)
				return 1
			end

			local function manifestVersion(): (number, string?)
				if pesdeRoot == nil then
					stdio.ewrite(`{ERROR_PREFIX} Failed to discover pesde package root\n`)
					return 1, nil
				end

				-- Use _G.PESDE_ROOT to get the install directory, then decode the
				-- pesde manifest to get the version of the tool dynamically
				local manifestContents = pathfs.readFile(pathfs.Path.from(pesdeRoot :: string):join("pesde.toml"))
				local ok, manifest: manifest.PesdeManifest = pcall(serde.decode, "toml" :: "toml", manifestContents)
				if not ok then
					stdio.ewrite(
						`{ERROR_PREFIX} Failed to decode bundled manifest. This is probably a bug.\n\n{manifest}`
					)
					return 1, nil
				end

				return 0, manifest.version
			end

			local versionOrDefault: string = version :: string
			if versionOrDefault == "" then
				local code, ver = manifestVersion()
				if code ~= 0 then
					return code
				end
				versionOrDefault = ver :: string
			end

			local toolId = string.gsub(repo :: string, "/", "+")
			local toolAlias = string.split(toolId, "+")[2]
			local toolInstallPath = TOOL_STORAGE_DIR:join(toolId):join(versionOrDefault):join(toolAlias)

			if pathfs.isFile(toolInstallPath) then
				return lib.runTool(toolInstallPath)
			end

			local ok, err = pcall(
				lib.installTool,
				{
					alias = Option.None,
					repo = repo,
					version = Option.Some(versionOrDefault),
				} :: ToolId,
				toolInstallPath
			)

			if not ok then
				-- Cleanup progress bar in case of error
				barFns.stop(bar)

				stdio.ewrite(`{ERROR_PREFIX} Failed to install {tool}\n`)
				stdio.ewrite(`	- {err}\n`)
				return 1
			end

			return 0
		end,
	}
)
