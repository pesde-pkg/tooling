local toolchainlib = require("../lune_packages/core")

return function(version)
	do
		local exit_code =
			toolchainlib("johnnymorganz/luau-lsp", "bins/luau-lsp", { "analyze", "bins/luau-lsp/tests/bad_input.luau" })
		assert(exit_code ~= 0, `should error`)
	end
	do
		local exit_code = toolchainlib(
			"johnnymorganz/luau-lsp",
			"bins/luau-lsp",
			{ "analyze", "bins/luau-lsp/tests/good_input.luau" }
		)
		assert(exit_code == 0, `shouldnt error`)
	end
end
