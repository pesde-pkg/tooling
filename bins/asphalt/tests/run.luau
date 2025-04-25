local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")
local fs = require("@lune/fs")

return function(version)
	-- not working, needing support
	-- process.cwd = "bins/asphalt"	-- bcuz asphalt.toml must to be in the same directory
	-- process.args = { "sync", "--target debug" }
	local success, err = pcall(require, "bins/asphalt/init.luau")
	assert(success, `failed to execute asphalt: {err}`)

	assert(fs.isFile("bins/asphalt/tests/output/water_normal_map.png"), "uploaded asset not found")
end
