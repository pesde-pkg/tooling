local serde = require("@lune/serde")
local process = require("@lune/process")

local dirs = require("../lune_packages/dirs")
local pathfs = require("../lune_packages/pathfs")

local revTable = require("./utils/rev_table")
local CommandBuilder = require("./utils/exec")
local types = require("./utils/result_option_conv")
local Option = types.Option
type Option<T> = types.Option<T>
local Result = types.Result
type Result<T, E> = types.Result<T, E>

export type CompressionFormat = "TarGz" | "TarXz" | "Zip"

local function detectFormat(fileName: string): Option<CompressionFormat>
	local fileNameParts = string.split(string.lower(fileName), ".")
	revTable(fileNameParts)

	if fileNameParts[1] == "zip" then
		return Option.Some("Zip" :: CompressionFormat) :: Option<unknown>
	end

	if fileNameParts[2] == "tar" then
		if fileNameParts[1] == "gz" then
			return Option.Some("TarGz" :: CompressionFormat) :: Option<unknown>
		end

		if fileNameParts[1] == "xz" then
			return Option.Some("TarXz" :: CompressionFormat) :: Option<unknown>
		end
	end

	return Option.None :: Option<CompressionFormat>
end

-- TODO: Use a type function to make all CompressionFormat lowercase
local decompress: { [CompressionFormat]: (compressed: buffer) -> Result<pathfs.AsPath, string> } = {
	Zip = function(compressed: buffer)
		-- FIXME: remove any usage
		return (Option.from(dirs.cacheDir()):map(function(cacheDir)
			local progCacheDir = cacheDir:join("pesde-bin")
			if not pathfs.isDir(progCacheDir) then
				pathfs.writeDir(progCacheDir)
			end

			return progCacheDir :: pathfs.AsPath
		end) :: Option<any>):match({
			Some = function(dir)
				-- Generate a unique file name and write the contents to the temporary file
				local tmpFile = dir:join(`{serde.hash("blake3", compressed)}.zip`)
				local tmpFilePath = tmpFile:toString()
				pathfs.writeFile(tmpFile, compressed)

				-- Create the directory to decompress into
				local decompressedDir = pathfs.Path.from(tmpFile):withExtension("")
				pathfs.writeDir(decompressedDir)

				-- Run unzip to decompress the file
				local child = CommandBuilder
					.new("unzip")
					:withArgs({ tmpFilePath, "-d", decompressedDir:toString() })
					-- FIXME: remove unknown usage
					:withStdioStrategy({
						stdout = Option.Some("pipe" :: CommandBuilder.StdioStrategy) :: Option<unknown>,
						stderr = Option.Some(
							if process.env.PESDE_LOG == "debug"
								then "forward"
								else "pipe" :: CommandBuilder.StdioStrategy
						) :: Option<unknown>,
					} :: CommandBuilder.IoStrategyMapping)
					:intoChildProcess()

				child:start()
				local status = child:waitForChild()

				-- Cleanup temporary file and handle errors
				pathfs.removeFile(tmpFile)
				if not status.ok then
					return Result.Err(
							`DecompressError::CommandFailed(exitCode={status.code})`
						) :: Result<pathfs.AsPath, string>
				end

				return Result.Ok(decompressedDir) :: Result<pathfs.AsPath, string>
			end,

			None = function()
				return Result.Err("DecompressError::NoCacheDir") :: Result<pathfs.AsPath, string>
			end,
		})
	end,

	-- TODO: Other formats
}

return { decompress = decompress, detectFormat = detectFormat }
