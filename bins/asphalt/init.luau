local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("jackTabsCode/asphalt", _G.PESDE_ROOT)

return process.exit(exitCode)
