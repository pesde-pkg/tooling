local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")
local fs = require("@lune/fs")

return function(version)
	-- not working, needing support
	-- process.args = { "sourcemap", "bins/argon/tests/input.project.json", "--output bins/argon/tests/output/sourcemap.json" }
	local success, err = pcall(require, "bins/argon/init.luau")
	assert(success, `failed to execute argon: {err}`)

	assert(fs.isFile("bins/argon/tests/output/sourcemap.luau"), `output not found`)
end
