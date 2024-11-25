--> Run stylua to check for formatting errors

local process = require("@lune/process")

local CommandBuilder = require("./exec")

process.exit(
	CommandBuilder.new("pesde")
		:withArgs({ "run", "./bins/stylua" })
		:withArg("--")
		:withArgs(process.args)
		:withStdioStrategy("forward")
		:exec().code
)
