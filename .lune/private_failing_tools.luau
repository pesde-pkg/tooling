local pathfs = require("../lune_packages/pathfs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

-- defs
local BINS_SRC_DIR = pathfs.getAbsolutePathOf(pathfs.Path.from("bins"))
local INFO_PREFIX = `{stdio.color("green")}{stdio.style("bold")}info{stdio.color("reset")}:`

-- functions
local function confirmAndClear(msg: string, default: boolean?): boolean
	local yes = stdio.prompt("confirm", msg, default)
	stdio.write(
		-- Move to the previous line, clear it, move cursor to start of line,
		-- and show cursor (if hidden)
		"\x1b[A\x1b[K\x1b[0G\x1b[?25h"
	)

	return yes
end

-- code
for _, binSrc in pathfs.readDir(BINS_SRC_DIR) do
	local absPath = BINS_SRC_DIR:join(binSrc)
	local testsPath = absPath:join("tests/run.luau")
	local manifestPath = absPath:join("pesde.toml")
	local manifestContents = pathfs.readFile(manifestPath)
	local manifest = serde.decode("toml", manifestContents)

	-- Check if the tool has any tests, and run them if they do
	if not pathfs.isFile(testsPath) then
		warn(`Unit tests not found for {binSrc}, assuming that they pass`)
		continue
	end
	local success, result = pcall(require, testsPath:toString())
	if not success then
		warn(`couldnt possible run tests for '{binSrc}'\n{result}`)
		continue
	end

	success, result = pcall(result, manifest.version)
	local should_private = not success

	if manifest.private == should_private then
		continue
	end
	local oldField = string.gsub(serde.encode("toml", { private = manifest.private }), "%s+$", "")
	local newField = string.gsub(serde.encode("toml", { private = not success }), "%s+$", "")

	local updatedManifest, replaces =
		string.gsub(manifestContents, string.gsub(oldField, "=%s*(%S+)", "%1"), newField, 1)

	assert(replaces == 1, `failed to replace 'private' field in manifest`)

	local toWrite = table.find(process.args, "--yes")
		or table.find(process.args, "-y")
		or confirmAndClear(`Update manifest for {binSrc}?`, false)

	if not toWrite then
		continue
	end

	print(
		`{INFO_PREFIX} Updated manifest {stdio.style("dim")}{manifestPath:stripPrefix(pathfs.cwd)}{stdio.style("reset")}`
	)
	pathfs.writeFile(manifestPath, updatedManifest)
end
