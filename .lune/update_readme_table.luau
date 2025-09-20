--> Updates the table in the README with the latest versions of tools

local stdio = require("@lune/stdio")
local process = require("@lune/process")
local net = require("@lune/net")

local pathfs = require("../lune_packages/pathfs")
local base64 = require("../lune_packages/base64")

local START_TIME = os.clock()

local README_PATH = pathfs.Path.from("./README.md")
local BINS_DIR = pathfs.Path.from("./bins")

local README_TABLE_START = "<!-- @@ table_start @@ -->"
local README_TABLE_END = "<!-- @@  table_end  @@ -->"
local BADGE_LIST_START = "<!-- @@ badge_list_start @@ -->"

local COLUMN_HEADERS = [[
| Tool                                                          | Available package                       |
|---------------------------------------------------------------|:----------------------------------------|]]

local pesdeLogoBlob = buffer.fromstring(pathfs.fs.readFile("./.lune/assets/pesde.svg"))
local PESDE_LOGO_URL = `data:image/svg%2bxml;base64,{buffer.tostring(base64.encode(pesdeLogoBlob))}`

local readme = pathfs.fs.readFile(README_PATH)

local function error(msg: string): never
	local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`
	stdio.ewrite(`{ERROR_PREFIX} {msg}\n`)
	return process.exit(1)
end

local function info(msg: string)
	local INFO_PREFIX = `{stdio.color("green")}{stdio.style("bold")}info{stdio.color("reset")}:`
	stdio.write(`{INFO_PREFIX} {msg}\n`)
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

local _, startPos = string.find(readme, README_TABLE_START, nil, true)
local tableEndMarkerStart = string.find(readme, README_TABLE_END, nil, true)
local _, badgeListStartMarker = string.find(readme, BADGE_LIST_START, nil, true)

if startPos == nil or tableEndMarkerStart == nil or badgeListStartMarker == nil then
	error("README table / badge list start or end marker not found")
end

local before, after =
	string.sub(readme, 1, startPos :: number),
	string.sub(readme, tableEndMarkerStart :: number, badgeListStartMarker :: number)

local urlList = {}
local rows = {
	`<div align="center">\n`,
	COLUMN_HEADERS,
}
for _, packageDir in pathfs.fs.readDir(BINS_DIR) do
	local fullPackageName = `pesde/{packageDir}`
	local manifestUrl =
		net.urlEncode(`https://raw.githubusercontent.com/pesde-pkg/tooling/main/bins/{packageDir}/pesde.toml`)
	local endpointParams = ""
		.. `url={manifestUrl}`
		.. "&query=version"
		.. `&prefix={net.urlEncode(fullPackageName .. "@")}`
		.. "&style=plastic"
		.. "&label=pesde"
		.. "&color=F19D1E"
		.. `&logo={PESDE_LOGO_URL}`

	local badgeUrlId = `{string.upper(packageDir)}_BADGE`

	local nameColumn = `[\`{fullPackageName}\`](https://pesde.dev/packages/{fullPackageName})`
	local badgeColumn = `![{badgeUrlId}]`

	local badgeUrl = `https://img.shields.io/badge/dynamic/toml?{endpointParams}`

	table.insert(urlList, `[{badgeUrlId}]: {badgeUrl}`)
	table.insert(
		rows,
		`| {nameColumn}{string.rep(" ", 62 - #nameColumn)}| {badgeColumn}{string.rep(" ", 39 - #badgeColumn)} |`
	)
end

table.insert(rows, "\n</div>\n")

local formattedTable = table.concat(rows, "\n")
local formattedBadgeUrls = table.concat(urlList, "\n")

local newReadme = string.format("%s\n%s%s\n%s\n", before, formattedTable, after, formattedBadgeUrls)

if newReadme == readme then
	info("README table is already up to date!")
	return
end

info("Changes in README table required, updating...")
local toWrite = table.find(process.args, "--yes")
	or table.find(process.args, "-y")
	or confirmAndClear("Overwrite current README?", false)

if toWrite then
	pathfs.fs.writeFile(README_PATH, newReadme)
end

local timeElapsed = string.format("%.2fs", os.clock() - START_TIME)
info(`Finished updating README badge table in {stdio.style("dim")}{timeElapsed}{stdio.style("reset")}!`)
