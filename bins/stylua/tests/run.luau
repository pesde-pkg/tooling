local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")

return function(version)
	do
		-- not working, needing support
		-- process.args = { "--check bins/stylua/tests/bad_input.luau", "--output-format summary" }
		local success, result = pcall(require, "bins/stylua/init.luau")
		assert(success, `failed to execute stylua: {result}`)

		assert(string.find(result, "Code style issues found"), `any expected error was found: {result}`)
	end

	do
		-- not working, needing support
		-- process.args = { "--check bins/stylua/tests/good_input.luau", "--output-format summary" }
		local success, result = pcall(require, "bins/stylua/init.luau")
		assert(success, `failed to execute stylua: {result}`)

		assert(string.find(result, "All files are correctly formatted."), `a unexpected error was found: {result}`)
	end
end
