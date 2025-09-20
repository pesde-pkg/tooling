local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("argon-rbx/argon", _G.PESDE_ROOT)

return process.exit(exitCode)
