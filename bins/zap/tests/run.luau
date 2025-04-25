local toolchainlib = require("../lune_packages/core")
local process = require("@lune/process")
local fs = require("@lune/fs")

-- not working, needing support
-- process.args = { "bins/zap/tests/input.zap" }
local success, err = pcall(require, "bins/zap/init.luau")

assert(success, `failed to execute zap: {err}`)

assert(fs.readFile("tests/output/client.luau") == fs.readFile("tests/snapshots/client.luau"), `invalid output`)
assert(fs.readFile("tests/output/server.luau") == fs.readFile("tests/snapshots/server.luau"), `invalid output`)
