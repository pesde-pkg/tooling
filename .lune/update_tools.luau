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

local function stripToolchainlibRev(version: string)
	version = version:gsub("[%.|%-]?toolchainlib%.%d+", ""):gsub("%+$", "")

	return version
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

local BINS_SRC_DIR = pathfs.absolute(pathfs.Path.from("bins"))

type Package = {
	name: string,
	path: pathfs.Path,
	repo: string,
	gh: Github.Github,
	manifestContents: string,
	manifest: manifestTypes.PesdeManifest,
	entrypointContents: string,
}

--- name -> package
type PackageMap = { [string]: Package }

type VersionChange = {
	old: string,
	new: string,
}

local function getPackage(packagePath: pathfs.Path): Package
	local entrypointPath = packagePath:join("init.luau")
	local manifestPath = packagePath:join("pesde.toml")

	assert(
		pathfs.fs.isFile(entrypointPath) and pathfs.fs.isFile(manifestPath),
		`No manifest or entrypoint found in '{packagePath}'`
	)

	local manifestContents = pathfs.fs.readFile(manifestPath)
	local manifest: manifestTypes.PesdeManifest = serde.decode("toml", manifestContents)
	local entrypointContents = pathfs.fs.readFile(entrypointPath)

	local repoName = string.match(entrypointContents, 'require%("@self/lune_packages/toolchainlib"%)%("([^"]+)"')
	local version = manifest.version
	local packageName = manifest.name and manifest.name:split("/")[2]

	assert(repoName ~= nil, `Failed to get repo name for '{packagePath}'`)
	assert(packageName ~= nil, `Invalid package name in '{manifestPath}'`)
	assert(version ~= nil, `No version in '{manifestPath}'`)

	local gh = Github.new(
		repoName :: string,
		Option.Some({
			authToken = Option.from(process.env.GITHUB_TOKEN),
			retries = Option.None,
		})
	)

	return {
		name = packageName,
		path = packagePath,
		repo = repoName :: string,
		gh = gh,
		manifestContents = manifestContents,
		manifest = manifest,
		entrypointContents = entrypointContents,
	}
end

local function getPackages(packagesDir: pathfs.Path): PackageMap
	local packages = {}

	for _, name in pathfs.fs.readDir(packagesDir) do
		local package = getPackage(packagesDir:join(name))
		packages[package.name] = package
	end

	return packages
end

local function fetchNewPackageVersions(packages: PackageMap): { [string]: { string } }
	local newPackageVersions = {}

	for _, package in packages do
		local transactions = package.gh:queueTransactions({ "FetchReleases" })
		local releasesResult = transactions[1] :: Result<Github.GithubReleases, any>

		releasesResult:match({
			Ok = function(releases)
				-- Order releases by published date
				table.sort(releases, function(a, b)
					return isoDateToTimestamp(a.published_at) < isoDateToTimestamp(b.published_at)
				end)

				-- Find new releases
				local newVersions = {}
				local versionIdx = math.huge
				for idx, release in releases do
					if stripLeadingVersion(release.tag_name) == stripToolchainlibRev(package.manifest.version) then
						versionIdx = idx
						continue
					end

					if idx > versionIdx then
						table.insert(newVersions, release.tag_name)
					end
				end

				if #newVersions > 0 then
					newPackageVersions[package.name] = newVersions
				end

				return nil
			end,
			Err = function(err)
				stdio.ewrite(`{ERROR_PREFIX} Could not fetch releases for '{package.repo}': {err}\n`)

				return nil
			end,
		})
	end

	return newPackageVersions
end

local function updatePackage(package: Package, newVersion: string)
	-- HACK: To prevent messing with our existing toml ordering and formatting
	-- we just replace the old version field string with the new version field
	-- string

	-- the string returned by serde.encode end with newlines, so remove them to
	-- maintain compatibility with different line endings
	local oldField = string.gsub(serde.encode("toml", { version = package.manifest.version }), "%s+$", "")
	local newField = string.gsub(serde.encode("toml", { version = stripLeadingVersion(newVersion) }), "%s+$", "")

	local updatedManifest, replaceCount = string.gsub(
		package.manifestContents,
		-- Escape any special characters that might be present in the version
		-- string, since this is interpreted as a string pattern.
		string.gsub(oldField, "[%.%+%-]", "%%%0"),
		newField,
		-- Only replace the first occurrence to be safe
		1
	)

	if replaceCount == 0 then
		error("Failed to replace version field in manifest.")
	end

	pathfs.fs.writeFile(package.path:join("pesde.toml"), updatedManifest)

	-- Fetch README for the tool repo, if present
	local transactions = package.gh:queueTransactions({
		{
			type = "Custom",
			payload = {
				method = "GET",
				url = `https://api.github.com/repos/{package.repo}/readme?ref={newVersion}`,
			},
		},
	})

	local contentsResult = transactions[1] :: Result<GithubContents, string>

	contentsResult
		:andThen(function(resp: GithubContents)
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
		:match({
			Ok = function(readmeContents)
				local readmePath = package.path:join("README.md")

				-- There used to be some issues with encoding if not deleted and recreated
				pathfs.fs.removeFile(readmePath)
				pathfs.fs.writeFile(readmePath, readmeContents)

				return nil
			end,
			Err = function(err)
				stdio.ewrite(`{ERROR_PREFIX} Could not fetch README for '{package.repo}': {err}\n`)

				return nil
			end,
		})
end

local function printNewPackageVersions(newPackageVersions: { [string]: { string } })
	-- The length operator does not work on dictionaries.
	local count = 0

	for packageName, newVersions in newPackageVersions do
		count += 1

		local prefix = `{packageName}: `
		local versionsStr = table.concat(newVersions, ", ")

		print(
			`{stdio.style("bold")}{prefix}{stdio.style("reset")}{stdio.color("cyan")}{versionsStr}{stdio.color("reset")}`
		)
	end

	if count == 0 then
		print("No updates found.")
	end
end

local OPTION: string? = "OPTION"
local FLAG: true? = true
local function parseArgs<T>(args: { string }, schema: T): (T, { string })
	local idx = 1

	local options: { [string]: unknown } = {}
	local positional: { string } = {}

	while idx <= #args do
		local arg = args[idx]
		idx += 1

		if arg:sub(1, 2) == "--" then
			local name = arg:sub(3)
			local kind = (schema :: any)[name]
			if kind == OPTION then
				local value = args[idx]
				idx += 1
				assert(value ~= nil, `No value given for '{name}'`)

				options[name] = value
			elseif kind == FLAG then
				options[name] = true
			end
		else
			table.insert(positional, arg)
		end
	end

	return options :: any, positional
end

local options, positional = parseArgs(process.args, {
	json = FLAG,
})

local function info(message: string)
	if not options.json then
		print(`{INFO_PREFIX} {message}`)
	end
end

local function printJson(data: unknown)
	if options.json then
		print(serde.encode("json", data))
	end
end

if #positional > 0 then
	-- Do a package update.

	local packageName = positional[1]
	local newVersion = positional[2]
	assert(newVersion ~= nil, "No version given.")

	local packagePath = BINS_SRC_DIR:join(packageName)
	assert(pathfs.fs.isDir(packagePath), "Invalid package name given.")
	local package = getPackage(packagePath)

	info(`Updating package '{packageName}' to '{newVersion}'...`)

	local startTime = os.clock()
	updatePackage(package, newVersion)
	local timeElapsed = string.format("%.2fs", os.clock() - startTime)

	info(`Updated package in {stdio.style("bold")}{timeElapsed}{stdio.style("reset")}!`)

	printJson({ ok = true })
else
	-- Fetch new updates.

	local packages = getPackages(BINS_SRC_DIR)
	info("Fetching for tool updates.")

	local startTime = os.clock()
	local newPackageVersions = fetchNewPackageVersions(packages)
	local timeElapsed = string.format("%.2fs", os.clock() - startTime)

	info(`Finished checking for tool updates in {stdio.style("bold")}{timeElapsed}{stdio.style("reset")}!`)

	if options.json then
		printJson(newPackageVersions)
	else
		print()
		printNewPackageVersions(newPackageVersions)
		print()
		info("Run 'lune run update_tools <package> <version>' to update a package.")
	end
end
