local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("1Axen/blink", _G.PESDE_ROOT)

return process.exit(exitCode)
