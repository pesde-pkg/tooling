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

local pathfs = require("../lune_packages/pathfs")
local dirs = require("../lune_packages/dirs")
local semver = require("../luau_packages/semver")

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
	version: Option<semver.SemverImpl>,
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

local function runTool(path: pathfs.Path)
	-- TODO: Fixup our wrapper and use that instead in the future
	process.spawn(path:toString(), process.args, {
		stdio = "forward",
		shell = true,
	})
end

local TOOL_INSTALL_DIR = (dirs.homeDir() or error("Couldn't get home dir :(")):join(".pesde"):join("bin")

function installTool(tool: ToolId)
	local toolStart = os.clock()
	local toolAlias = tool.alias:unwrapOr(string.split(tool.repo, "/")[2])
	print("toolAlias defaulting took", os.clock() - toolStart)
	
	local installStart = os.clock()
	local toolInstallPath = TOOL_INSTALL_DIR:join(toolAlias)
	print("toolInstallPath joining took", os.clock() - installStart)

	-- TODO: In order to eliminate fs read overhead on startup and to disallow
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
		Some = function(version: semver.SemverImpl)
			for _, release in releases do
				if semver.parse(release.tag_name):unwrap() :: semver.SemverImpl == version then
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

	-- TODO: Maintain multiple versions of a tool, and avoid downloading
	-- the binary for a version again if it's already there 
	pathfs.move(binaryPath, toolInstallPath)
	runTool(toolInstallPath)
end

return {
	installTool = installTool,
	runTool = runTool
}