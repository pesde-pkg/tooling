local toolchainlib = require("../lune_packages/core")
local fs = require("@lune/fs")

return function(version)
	local exit_code = toolchainlib(
		"rojo-rbx/rojo",
		"bins/rojo",
		{ "sourcemap", "bins/rojo/tests/input.project.json", "--output", "bins/rojo/tests/output/sourcemap.json" }
	)
	assert(exit_code == 0, `shouldnt error`)

	assert(fs.isFile("bins/rojo/tests/output/sourcemap.json"), `output not found`)
end
