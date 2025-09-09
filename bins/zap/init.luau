-- TODO: Make use of returned exit code. Currently this script will get
-- required by a pesde generated linker script, and due to a lune bug,
-- exiting from within a required module causes a non-winding panic

-- See https://github.com/lune-org/lune/pull/247 for more details

require("@self/lune_packages/toolchainlib")("red-blox/zap", _G.PESDE_ROOT)

return nil
