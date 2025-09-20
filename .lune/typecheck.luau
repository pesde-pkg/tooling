--> Run luau-lsp analysis to check for type errors

local process = require("@lune/process")

local CommandBuilder = require("./exec")

process.exit(
	CommandBuilder.new("pesde")
		:withArgs({ "run", "./bins/luau_lsp" })
		:withArgs({ "--", "analyze" })
		:withArgs({ "--settings", ".vscode/settings.json" })
		:withArgs({ "--ignore", "'**/*_packages/**'" })
		:withArgs({ "--platform", "standard" })
		:withArg(".")
		:withStdioStrategy("forward")
		:exec().code
)
