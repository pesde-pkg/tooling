--> Run luau-lsp analysis to check for type errors

local process = require("@lune/process")

local CommandBuilder = require("./exec")

process.exit(
	CommandBuilder.new("pesde")
		:withArgs({ "run", "./bins/luau-lsp" })
		:withArgs({ "--", "analyze" })
		:withArgs({ "--settings", ".vscode/settings.json" })
		:withArgs({ "--ignore", "'**/*_packages/**'" })
		:withArg(".")
		:withStdioStrategy("forward")
		:exec().code
)
