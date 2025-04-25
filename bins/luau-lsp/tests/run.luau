local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")
local fs = require("@lune/fs")

return function(version)
	-- not working, needing support
	-- process.args = { "process bins/darklua/tests/input.luau bins/darklua/tests/output.luau" --format dense }
	local success, result = pcall(require, "bins/darklua/init.luau")
	assert(success, `failed to execute darklua: {result}`)

	assert(
		fs.readFile("bins/darklua/tests/output.luau") ~= fs.readFile("bins/darklua/tests/input.luau"),
		`any expected error was found: {result}`
	)
end
