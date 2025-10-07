local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("watchexec/watchexec", _G.PESDE_ROOT)

return process.exit(exitCode)
