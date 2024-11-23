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

local function downloadAndDecompress(asset: {
	name: string,
	browser_download_url: string,
	size: number,
	content_type: string,
}): pathfs.Path
	local contentsResp = net.request(asset.browser_download_url)
	if not contentsResp.ok then
		return error(`Failed to download asset {asset.name}: HTTP Code {contentsResp.statusCode}`)
	end

	local decompressedPath = compression.decompress
		[compression.detectFormat(asset.name):unwrap()](buffer.fromstring(contentsResp.body))
		:unwrap() :: pathfs.Path

	return decompressedPath
end

local function chmod(path: pathfs.Path, mode: number)
	if process.os ~= "windows" then
		local child = process.spawn("chmod", { string.format("%o", mode), path:toString() })
		if not child.ok then
			error(`chmod failed: {path} - {child.stderr}`)
		end
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

function installTool(tool: ToolId)
	local toolAlias = toolAliasOrDefault(tool)
	local toolId = string.gsub(tool.repo, "/", "+")
	local toolInstallPath = TOOL_STORAGE_DIR:join(toolId)
		:join(`{toolAlias}-` .. tostring(tool.version:map(tostring):unwrapOr("latest")))

	if pathfs.isFile(toolInstallPath) then
		runTool(toolInstallPath)
		return
	end

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
		local desc = PlatformDescriptor.fromString(asset.name):unwrap()
		if eq(currentDesc, desc) then
			matchingAsset = asset
		end
	end

	local binaryPath: pathfs.Path
	if matchingAsset == nil then
		warn("No matching asset found, downloading all assets")
		for _, asset in assets do
			local decompressedPath = downloadAndDecompress(asset)

			for _, file in pathfs.readDir(decompressedPath) do
				local filePath = decompressedPath:join(file)
				local nativeDesc = PlatformDescriptor.fromExecutable(filePath:toString()):unwrap()

				if eq(currentDesc, nativeDesc) then
					binaryPath = filePath
					break
				end
			end
		end
	else
		local decompressedPath = downloadAndDecompress(matchingAsset)
		binaryPath = decompressedPath:join(aliasPath)
		if not pathfs.isFile(binaryPath) then
			error(`No matching binary found in {decompressedPath}`)
		end
	end

	-- Maintain multiple versions of a tool, and avoid downloading
	-- the binary for a version again if it's already there
	local toolDir = Option.from(toolInstallPath:parent()):unwrap()
	if not pathfs.isFile(toolDir) then
		pathfs.writeDir(toolDir)
	end

	pathfs.move(binaryPath, toolInstallPath)

	-- In order to eliminate fs read overhead on startup and to disallow
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

	local linkPath = LINK_INSTALL_DIR:join(toolAlias)
	pathfs.writeFile(
		linkPath,
		string.format(
			[[#!/bin/env -S lune run

			local serde = require("@lune/serde")
			local process = require("@lune/process")
			local fs = require("@lune/fs")	
			
			local TOOL_NAME = "%s"
			--TOOL_PATH_BEGIN--
			local TOOL_PATH = "%s"
			--TOOL_PATH_END--

			local IS_DEV = true
			local PLATFORM_SEP = if process.platform == "windows" then "\\" else "/"

			-- TODO: Check whether we are being run as `pesde x` and skip this check
			-- That would involve getting the file path like this, probably:
			local selfPathInfo = debug.info(1, "s")
			local selfPath = string.sub(selfPathInfo, 10, #selfPathInfo - 2)

			-- FIXME: Does the CWD have a trailing slash on all platforms?
			local manifestContents = fs.readFile(`{process.cwd}{PLATFORM_SEP}pesde.toml`)
			local ok, manifest = pcall(serde.decode, "toml", manifestContents)
			if not ok then
				error(`Failed to parse pesde.toml: {tostring(manifest)}`)
			end

			local isInstalled = IS_DEV
			if manifest.dev_dependencies ~= nil then
				for package, _ in manifest.dev_dependencies do
					if package == TOOL_NAME then
						isInstalled = true
						break
					end
				end
			end

			if not isInstalled then
				error(`Tool {TOOL_NAME} in any pesde manifest file!`)
			end

			process.exit(process.spawn(TOOL_PATH, process.args, {
				stdio = "forward",
				cwd = process.cwd,
				env = process.env,
			}).code)]],
			string.split(toolId, "+")[2],
			toolInstallPath:toString()
		)
	)
	chmod(linkPath, 0b111101101)
end

return {
	runTool = runTool,
	installTool = installTool,
}
