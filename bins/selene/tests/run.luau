local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")

return function(version)
	do
		-- not working, needing support
		-- process.args = { "bins/selene/tests/bad_input.luau" }
		local success, result = pcall(require, "bins/selene/init.luau")
		assert(success, `failed to execute selene: {result}`)

		assert(
			string.find(result, "%d warnings") or string.find(result, "%d errors"),
			`any expected error was found: {result}`
		)
	end

	do
		-- not working, needing support
		-- process.args = { "bins/selene/tests/good_input.luau" }
		local success, result = pcall(require, "bins/selene/init.luau")
		assert(success, `failed to execute selene: {result}`)

		assert(
			string.find(result, "0 warnings") or string.find(result, "0 errors"),
			`a unexpected error was found: {result}`
		)
	end
end
