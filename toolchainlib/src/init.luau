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

local Semver = require("../luau_packages/semver")
local pathfs = require("../lune_packages/pathfs")
local dirs = require("../lune_packages/dirs")

local types = require("./utils/result_option_conv")
local Option = types.Option
type Option<T> = types.Option<T>

local Github = require("./github")
local PlatformDescriptor = require("./platform/descriptor")
local compression = require("./compression")
local eq = require("./utils/eq")

export type ToolId = {
	alias: Option<string>,
	repo: string,
	version: Option<Semver.SemverImpl>,
}

export type GithubReleases = {
	{
		tag_name: string,
		prerelease: boolean,
		draft: boolean,
		assets: {
			{
				name: string,
				browser_download_url: string,
				size: number,
				content_type: string,
			}
		},
	}
}

local WARN_PREFIX = `{stdio.color("yellow")}{stdio.style("bold")}warn{stdio.color("reset")}:`

local function warn(...)
	stdio.ewrite(`{WARN_PREFIX} {stdio.format(...)}\n`)
end

local function downloadAndDecompress(asset: {
	name: string,
	browser_download_url: string,
	size: number,
	content_type: string,
}): Option<pathfs.Path>
	-- TODO: Small optimization by first detecting that its a valid format we support
	-- before downloading the file
	local contentsResp = net.request(asset.browser_download_url)
	if not contentsResp.ok then
		return error(`Failed to download asset {asset.name}: HTTP Code {contentsResp.statusCode}`)
	end

	return compression
			.detectFormat(asset.name)
			:map(function(format: compression.CompressionFormat)
				return compression.decompress[format](buffer.fromstring(contentsResp.body)):unwrap() :: pathfs.Path
			end) :: Option<pathfs.Path>
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

local LINK_INSTALL_DIR = (dirs.homeDir() or error("Couldn't get home dir :(")):join(".pesde"):join("bin")
local TOOL_STORAGE_DIR = LINK_INSTALL_DIR:join("tool_storage")

function runTool(tool: ToolId | pathfs.Path): number
	-- FIXME: `process.spawn` has a bug where interactive features don't
	-- forward properly
	local toolId = tool :: ToolId
	local path = if toolId.alias ~= nil then LINK_INSTALL_DIR:join(toolAliasOrDefault(toolId)) else tool :: pathfs.Path

	return process.spawn(path:toString(), process.args, {
		cwd = process.cwd,
		env = process.env,
		stdio = "forward",
	}).code
end

function installTool(tool: ToolId, installPath: pathfs.Path)
	local toolAlias = toolAliasOrDefault(tool)
	local client = Github.new(
		tool.repo,
		Option.Some({
			-- TODO: Maybe use the `gh auth token` command to get the token
			authToken = Option.from(process.env.GITHUB_TOKEN) :: Option<string>,
			retries = Option.None :: Option<number>,
		}) :: Option<Github.Config>
	)

	local releases = client:queueTransactions({ "FetchReleases" })[1]:unwrap() :: GithubReleases
	local assets = tool.version:match({
		Some = function(version: Semver.SemverImpl)
			for _, release in releases do
				if Semver.parse(release.tag_name):unwrap() :: Semver.SemverImpl == version then
					return release.assets
				end
			end

			return error(`No release found for version {version}`)
		end,

		None = function()
			return releases[0].assets
		end,
	})

	-- TODO: Use index type fn in solver v2
	local matchingAsset: {
		name: string,
		browser_download_url: string,
		size: number,
		content_type: string,
	}

	local currentDesc = PlatformDescriptor.currentSystem()
	local aliasPath = pathfs.Path.from(toolAlias):withExtension(if currentDesc.os == "windows" then "exe" else "")

	for _, asset in assets do
		local desc = PlatformDescriptor.fromString(asset.name)
		local descWithArch = desc:map(function(inner: PlatformDescriptor.PlatformDescriptor)
			-- FIXME: unknown usage
			return inner
		end)

		if descWithArch:isOk() and eq(currentDesc, descWithArch:unwrap()) then
			matchingAsset = asset
			break
		end
	end

	local binaryPath: pathfs.Path
	if matchingAsset == nil then
		warn("Pesde could not find a matching binary for your system")
		warn("Will now attempt to download all binaries and find a matching one")
		for _, asset in assets do
			local decompressedPath = downloadAndDecompress(asset)
			if decompressedPath:isSome() then
				local path = decompressedPath:unwrap()
				for _, file in pathfs.readDir(path) do
					local filePath = path:join(file)
					local nativeDesc = PlatformDescriptor.fromExecutable(filePath:toString()):unwrap()

					if eq(currentDesc, nativeDesc) then
						binaryPath = filePath
						break
					end
				end
			end
		end
	else
		local decompressedPath = downloadAndDecompress(matchingAsset):unwrap()
		binaryPath = decompressedPath:join(aliasPath)
		if not pathfs.isFile(binaryPath) then
			error(`No matching binary found in {decompressedPath}`)
		end
	end

	-- Maintain multiple versions of a tool, and avoid downloading
	-- the binary for a version again if it's already there
	local toolDir = Option.from(installPath:parent()):unwrap()
	if not pathfs.isFile(toolDir) then
		pathfs.writeDir(toolDir)
	end

	pathfs.move(binaryPath, installPath)

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

	-- NOTE: This is equivalent to `0o755` or `rwxr-xr-x`
	chmod(installPath, 0b10101010011)
	runTool(installPath)
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
			-- TODO: Progress bar maybe? :D

			local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

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
				-- TODO: Create a pesde manifest type in toolchainlib, and use that here
				local ok, manifest = pcall(serde.decode, "toml" :: "toml", manifestContents)
				if not ok then
					stdio.ewrite(
						`{ERROR_PREFIX} Failed to decode bundled manifest. This is probably a bug.\n\n{manifest}`
					)
					return 1, nil
				end

				return 0, manifest.version
			end

			local versionOrDefault = version
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

			local versionOrDefault: string = version :: string
			if versionOrDefault == "" then
				local code, ver = manifestVersion()
				if code ~= 0 then
					return code
				end
				versionOrDefault = ver :: string
			end

			local ok, err = pcall(
				lib.installTool,
				{
					alias = Option.None,
					repo = repo,
					version = Option.Some(Semver.parse(versionOrDefault):unwrap()) :: Option<Semver.SemverImpl>,
				} :: ToolId,
				toolInstallPath
			)

			if not ok then
				stdio.ewrite(`{ERROR_PREFIX} Failed to install {tool}\n`)
				stdio.ewrite(`	- {err}\n`)
				return 1
			end

			return 0
		end,
	}
)
