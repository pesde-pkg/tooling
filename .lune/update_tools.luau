--> Updates tooling bin versions and READMEs

local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local process = require("@lune/process")
local DateTime = require("@lune/datetime")

local pathfs = require("../lune_packages/pathfs")
local base64 = require("../lune_packages/base64")

local manifestTypes = require("../toolchainlib/src/manifest")
local Result = require("../lune_packages/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local Github = require("../toolchainlib/src/github")

type GithubContents = {
	name: string,
	path: string,
	sha: string,
	size: number,
	url: string,
	html_url: string,
	git_url: string,
	download_url: string,
	type: "file" | "dir" | "symlink",
	content: string,
	encoding: "base64",
	_links: {
		self: string,
		git: string,
		html: string,
	},
}

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
local WARN_PREFIX = `{stdio.color("yellow")}{stdio.style("bold")}warn{stdio.color("reset")}:`
local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local function warn(...)
	stdio.ewrite(`{WARN_PREFIX} {stdio.format(...)}\n`)
end

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
	local testsPath = absPath:join("tests/run.luau")
	local binEntrypoint = absPath:join("init.luau")
	local manifestPath = absPath:join("pesde.toml")
	local readmePath = absPath:join("README.md")

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

	local gh = Github.new(
		repoName :: string,
		Option.Some({
			authToken = Option.from(process.env.GITHUB_TOKEN) :: Option<string>,
			retries = Option.None :: Option<number>,
		} :: Github.Config) :: Option<Github.Config>
	)
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
		if stripLeadingVersion(release.tag_name) == version then
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

		-- Check if the tool has any tests, and run them if they do
		if pathfs.isFile(testsPath) then
			local success, result = pcall(require, testsPath:toString())
			if not success then
				continue
			end

			success, result = pcall(result, newVersion)
			if not success then
				continue
			end
		else
			warn(`Unit tests not found for {binSrc}, assuming that they pass`)
		end

		-- HACK: To prevent messing with our existing toml ordering and formatting
		-- we just replace the old version field string with the new version field
		-- string

		-- the string returned by serde.encode end with newlines, so remove them to maintain compatibility with different line endings
		-- Old version field string:
		local oldField = string.gsub(serde.encode("toml", { version = manifest.version }), "%s+$", "")

		-- New version field string:
		local newField = string.gsub(serde.encode("toml", { version = stripLeadingVersion(newVersion) }), "%s+$", "")

		local updatedManifest, replaces = string.gsub(
			manifestContents,
			string.gsub(oldField, "[%.%+%-]", "%%%0"),
			newField,
			-- Only replace the first occurrence to be safe
			1
		)
		if replaces == 0 then
			error("failed to replace version field in manifest")
		end

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
	end

	-- Fetch README for the tool repo, if present
	transactions = gh:queueTransactions({
		{
			type = "Custom",
			payload = {
				method = "GET",
				url = `https://api.github.com/repos/{repoName}/readme`,
			},
		},
	})

	local contentsResp = transactions[1] :: Result<GithubContents, string>

	local readmeRes = contentsResp:andThen(function(resp: GithubContents)
		-- If there was not an error, and the contents are base64 encoded,
		-- we decode the contents and return the decoded buffer
		if resp.encoding == "base64" then
			-- NOTE: Github uses a special format for encoding the contents, where it
			-- separates the entire file into multiple lines, and encodes each line in
			-- base64

			-- This should be done by the base64 library, but oh well
			local content = string.gsub(resp.content, "%s+", "")
			local decoded = base64.decode(buffer.fromstring(content))
			return Result.Ok(decoded)
		end

		return Result.Err(`Unsupported encoding: {resp.encoding}`)
	end)

	-- NOTE: Ideally this block should be a match, but I cannot make use of
	-- control flow expressions from within a function
	if readmeRes:isErr() then
		warn(`Failed to fetch README from tool repo {repoName}:`, readmeRes:unwrapErr())
		continue
	end

	-- Write the updated README to the tool's directory
	local readmeContents = readmeRes:unwrap()
	-- There used to be some issues with encoding if not deleted and recreated
	pathfs.removeFile(readmePath)
	pathfs.writeFile(readmePath, readmeContents)

	print(
		`{INFO_PREFIX} Wrote README to {stdio.style("dim")}{readmePath:stripPrefix(pathfs.cwd)}{stdio.style("reset")}`
	)
end

local timeElapsed = string.format("%.2fs", os.clock() - START_TIME)
print(`{INFO_PREFIX} Finished checking for tool updates in {stdio.style("dim")}{timeElapsed}{stdio.style("reset")}!`)
