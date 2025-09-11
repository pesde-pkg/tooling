--> Run stylua to check for formatting errors

local process = require("@lune/process")

local CommandBuilder = require("./exec")

process.exit(CommandBuilder.new("stylua"):withArgs(process.args):withStdioStrategy("forward"):exec().code)
