local serde = require("@lune/serde")
local process = require("@lune/process")

local dirs = require("../lune_packages/dirs")
local pathfs = require("../lune_packages/pathfs")

local Result = require("../lune_packages/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local revTable = require("./utils/rev_table")
local CommandBuilder = require("./utils/exec")

export type CompressionFormat = "TarGz" | "TarXz" | "Zip"

local function detectFormat(fileName: string): Option<CompressionFormat>
	local fileNameParts = string.split(string.lower(fileName), ".")
	revTable(fileNameParts)

	if fileNameParts[1] == "zip" then
		return Option.Some("Zip" :: CompressionFormat)
	end

	if fileNameParts[2] == "tar" then
		if fileNameParts[1] == "gz" then
			return Option.Some("TarGz" :: CompressionFormat)
		end

		if fileNameParts[1] == "xz" then
			return Option.Some("TarXz" :: CompressionFormat)
		end
	end

	return Option.None :: Option<CompressionFormat>
end

-- TODO: Use a type function to make all CompressionFormat lowercase
local decompress: { [CompressionFormat]: (compressed: buffer) -> Result<pathfs.AsPath, string> } = {
	Zip = function(compressed: buffer)
		return (Option.from(dirs.cacheDir()):map(function(cacheDir)
			local progCacheDir = cacheDir:join("pesde-bin")
			if not pathfs.isDir(progCacheDir) then
				pathfs.writeDir(progCacheDir)
			end

			return progCacheDir :: pathfs.Path
		end)):match({
			Some = function(dir: pathfs.Path)
				-- Generate a unique file name and write the contents to the temporary file
				local tmpFile = dir:join(`{serde.hash("blake3", compressed)}.zip`)
				local tmpFilePath = tmpFile:toString()
				pathfs.writeFile(tmpFile, compressed)

				-- Create the directory to decompress into
				local decompressedDir = pathfs.Path.from(tmpFile):withExtension("")
				pathfs.writeDir(decompressedDir)

				-- Run unzip to decompress the file
				local child = (if process.os == "windows"
					-- Thanks windows :)
					then CommandBuilder.new("powershell"):withArgs({
						"-ExecutionPolicy RemoteSigned",
						`-c \`"Import-Module Microsoft.PowerShell.Archive; Expand-Archive -LiteralPath '{tmpFilePath}' -DestinationPath '{decompressedDir:toString()}'\`"`,
					})
					else CommandBuilder.new("unzip"):withArgs({ tmpFilePath, "-d", decompressedDir:toString() }))
					:withStdioStrategy({
						-- Powershell on Windows writes errors to stdout. Bruh
						stdout = Option.Some(
							if process.os == "windows" and process.env.PESDE_LOG == "debug"
								then "forward"
								else "pipe" :: CommandBuilder.StdioStrategy
						),
						stderr = Option.Some(
							if process.env.PESDE_LOG == "debug"
								then "forward"
								else "pipe" :: CommandBuilder.StdioStrategy
						),
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
