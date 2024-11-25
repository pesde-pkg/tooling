--> Run luau-lsp analysis to check for type errors

local process = require("@lune/process")

local CommandBuilder = require("./exec")

local PLATFORM_SEP = if process.os == "windows" then ";" else ":"

process.exit(
	CommandBuilder.new("luau-lsp")
		:withArg("analyze")
		:withArgs({ "--settings", ".vscode/settings.json" })
		:withArgs({ "--ignore", "'**/*_packages/**'" })
		:withArg(".")
		:withStdioStrategy("forward")
		:exec().code
)
