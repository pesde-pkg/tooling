local toolchainlib = require("../lune_packages/core")
local fs = require("@lune/fs")

return function(version)
	local exit_code = toolchainlib(
		"argon-rbx/argon",
		"bins/argon",
		{ "sourcemap", "bins/argon/tests/input.project.json", "--output", "bins/argon/tests/output/sourcemap.json" }
	)
	assert(exit_code == 0, `shouldnt error`)

	assert(fs.isFile("bins/argon/tests/output/sourcemap.json"), `output not found`)
end
