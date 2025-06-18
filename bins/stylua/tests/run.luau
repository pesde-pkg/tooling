local toolchainlib = require("../lune_packages/core")

return function(version)
	do
		local exit_code =
			toolchainlib("johnnymorganz/stylua", "bins/stylua", { "bins/stylua/tests/bad_input.luau", "--check" })
		assert(exit_code ~= 0, `should error`)
	end

	do
		local exit_code =
			toolchainlib("johnnymorganz/stylua", "bins/stylua", { "bins/stylua/tests/good_input.luau", "--check" })
		assert(exit_code == 0, `shouldnt error`)
	end
end
