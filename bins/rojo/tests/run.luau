local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")
local fs = require("@lune/fs")

return function(version)
	-- not working, needing support
	-- process.args = { "sourcemap", "bins/rojo/tests/input.project.json", "--output bins/rojo/tests/output/sourcemap.json" }
	local success, err = pcall(require, "bins/rojo/init.luau")
	assert(success, `failed to execute rojo: {err}`)

	assert(fs.isFile("bins/rojo/tests/output/sourcemap.luau"), `output not found`)
end
