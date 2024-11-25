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
export type PlatformDescriptor = {
	os: process.OS,
	arch: Option<arch.Arch>,
	toolchain: Option<toolchain.Toolchain>,
}
type ExecutableDetectionResult = {
	os: Option<process.OS>,
	arch: Option<arch.Arch>,
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
	local detected = Option.from(detectFromExecutable(buffer.fromstring(binaryContents)))
		:map(function(inner: detectFromExecutable.ExecutableDetectionResult): ExecutableDetectionResult
			return {
				os = Option.from(inner.os) :: Option<process.OS>,
				arch = Option.from(inner.arch) :: Option<arch.Arch>,
			}
		end) :: Option<ExecutableDetectionResult>

	local platformDesc = detected:map(function(inner: ExecutableDetectionResult): PlatformDescriptor
		return {
			os = inner.os:unwrap(),
			arch = inner.arch :: Option<arch.Arch>,
			toolchain = Option.None :: Option<toolchain.Toolchain>,
		}
	end) :: Option<PlatformDescriptor>

	return platformDesc:okOr(
			"NoExecutableDetected" :: result.PlatformError
		) :: result.PlatformResult<PlatformDescriptor>
end

return PlatformDescriptor
