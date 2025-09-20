local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("seaofvoices/darklua", _G.PESDE_ROOT)

return process.exit(exitCode)
