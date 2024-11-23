local process = require("@lune/process")
local fs = require("@lune/fs")

local os = require("./os")
local arch = require("./arch")
local toolchain = require("./toolchain")
local result = require("./result")
local detectFromExecutable = require("./detection/executable")

local types = require("../utils/result_option_conv")
local Option = types.Option
local Result = types.Result
type Option<T> = types.Option<T>
type Result<T, E> = types.Result<T, E>

local PlatformDescriptor = {}
type PlatformDescriptor = {
	os: process.OS,
	arch: Option<arch.Arch>,
	toolchain: Option<toolchain.Toolchain>,
}

function PlatformDescriptor.currentSystem(): PlatformDescriptor
	return {
		os = process.os,
		arch = Option.Some(process.arch) :: Option<arch.Arch>,
		toolchain = Option.None :: Option<toolchain.Toolchain>,
	}
end

function PlatformDescriptor.fromString(str: string)
	local detectedOs = os.detect(str)
	if detectedOs:isNone() then
		return Result.Err("NoPatternDetected" :: result.PlatformError)
	end

	return Result.Ok({
		os = detectedOs:unwrap() :: process.OS,
		arch = arch.detect(str),
		toolchain = toolchain.detect(str),
	} :: PlatformDescriptor)
end

function PlatformDescriptor.fromExecutable(path: string): result.PlatformResult<PlatformDescriptor>
	local binaryContents = fs.readFile(path)
	local detected =
		Option.from(detectFromExecutable(buffer.fromstring(binaryContents))) :: Option<detectFromExecutable.ExecutableDetectionResult>
	local platformDesc = detected:map(function(inner: detectFromExecutable.ExecutableDetectionResult)
		local innerClone: PlatformDescriptor = table.clone(inner) :: any
		innerClone.toolchain = Option.None :: Option<toolchain.Toolchain>
		return innerClone
	end) :: Option<PlatformDescriptor>

	return platformDesc:okOr(
			"NoExecutableDetected" :: result.PlatformError
		) :: result.PlatformResult<PlatformDescriptor>
end

return PlatformDescriptor
