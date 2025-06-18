local toolchainlib = require("../lune_packages/core")
local fs = require("@lune/fs")

return function(version)
	local exit_code = toolchainlib("jacktabscode/asphalt", "bins/asphalt", { "bins/asphalt/tests/input" })
	assert(exit_code == 0, `shouldnt error`)

	assert(fs.isFile("bins/asphalt/tests/output/water_normal_map.png"), "uploaded asset not found")
end
