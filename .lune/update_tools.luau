local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local process = require("@lune/process")
local DateTime = require("@lune/datetime")

local pathfs = require("../lune_packages/pathfs")

local manifestTypes = require("../toolchainlib/src/manifest")
local types = require("../toolchainlib/src/utils/result_option_conv")
local Option = types.Option
type Option<T> = types.Option<T>
local Github = require("../toolchainlib/src/github")

local function isoDateToTimestamp(isoDate: string): number
	return DateTime.fromIsoDate(isoDate).unixTimestamp
end

local function stripLeadingVersion(version: string): string
	local stripped = string.gsub(version, "^v", "")
	return stripped
end

local function confirmAndClear(msg: string, default: boolean?): boolean
	local yes = stdio.prompt("confirm", msg, default)
	stdio.write(
		-- Move to the previous line, clear it, move cursor to start of line,
		-- and show cursor (if hidden)
		"\x1b[A\x1b[K\x1b[0G\x1b[?25h"
	)

	return yes
end

local INFO_PREFIX = `{stdio.color("green")}{stdio.style("bold")}info{stdio.color("reset")}:`
local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local function error(msg: string): never
	stdio.ewrite(`{ERROR_PREFIX} {msg}\n`)
	return process.exit(1)
end

local function assert(expr: boolean, msg: string)
	if not expr then
		error(msg)
	end
end

local START_TIME = os.clock()
local BINS_SRC_DIR = pathfs.getAbsolutePathOf(pathfs.Path.from("bins"))

for _, binSrc in pathfs.readDir(BINS_SRC_DIR) do
	local absPath = BINS_SRC_DIR:join(binSrc)
	local binEntrypoint = absPath:join("init.luau")
	local manifestPath = absPath:join("pesde.toml")

	-- Make sure our constructed entrypoint and manifest paths exist
	assert(
		pathfs.isFile(binEntrypoint) and pathfs.isFile(manifestPath),
		"Either binary entrypoint or manifest not found"
	)

	local manifestContents = pathfs.readFile(manifestPath)
	local manifest: manifestTypes.PesdeManifest = serde.decode("toml", manifestContents)
	local entrypointContents = pathfs.readFile(binEntrypoint)

	local repoName = string.match(entrypointContents, 'require%("./lune_packages/core"%)%("([^"]+)"')
	local version = manifest.version

	-- Make sure we have a repo name and version
	assert(repoName ~= nil, `Failed to get repo name for tool {binSrc}`)

	local gh = Github.new(repoName :: string, Option.None :: Option<Github.Config>)
	local transactions = gh:queueTransactions({ "FetchReleases" })

	-- Fetch releases, and order them by published date
	local releases = transactions[1]:unwrap() :: Github.GithubReleases
	table.sort(releases, function(a, b)
		return isoDateToTimestamp(a.published_at) < isoDateToTimestamp(b.published_at)
	end)

	-- Filter for only versions which are after the current version
	local releasesAfter = {}
	local versionIdx = math.huge
	for idx, release in releases do
		if release.tag_name == version then
			versionIdx = idx
			continue
		end

		if idx > versionIdx then
			releasesAfter[release.tag_name] = release
		end
	end

	for newVersion, newRelease in releasesAfter do
		print(
			`{INFO_PREFIX} Found new tool release {stdio.style("bold")}{binSrc}{stdio.style("reset")}@{stdio.style(
				"dim"
			)}{newVersion}{stdio.style("reset")}`
		)

		-- HACK: To prevent messing with our existing toml ordering and formatting
		-- we just replace the old version field string with the new version field
		-- string
		local updatedManifest = string.gsub(
			manifestContents,
			-- Old version field string:
			serde.encode("toml", { version = manifest.version }),
			-- New version field string:
			serde.encode("toml", { version = stripLeadingVersion(newVersion) }),
			-- Only replace the first occurrence to be safe
			1
		)

		local toWrite = table.find(process.args, "--yes")
			or table.find(process.args, "-y")
			or confirmAndClear(`Update manifest for {binSrc}?`, false)

		if toWrite then
			print(
				`{INFO_PREFIX} Updated manifest {stdio.style("dim")}{manifestPath:stripPrefix(pathfs.cwd)}{stdio.style(
					"reset"
				)}`
			)

			pathfs.writeFile(manifestPath, updatedManifest)
		end

		-- TODO: Also update the included README for the tool
	end
end

local timeElapsed = string.format("%.2fs", os.clock() - START_TIME)
print(`{INFO_PREFIX} Finished checking for tool updates in {stdio.style("dim")}{timeElapsed}{stdio.style("reset")}!`)
