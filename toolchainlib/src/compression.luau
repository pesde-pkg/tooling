local unzip = require("../luau_packages/unzip")

local Result = require("../lune_packages/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local revTable = require("./utils/rev_table")
local eq = require("./utils/eq")
local PlatformDescriptor = require("./platform/descriptor")

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
local extractBinary: {
	[CompressionFormat]: (
		compressed: buffer,
		binaryName: string,
		targetPlatform: PlatformDescriptor.PlatformDescriptor
	) -> Result<buffer, string>,
} =
	{
		Zip = function(compressed, binaryName, targetPlatform)
			local reader = unzip.load(compressed)

			local binaryEntry = reader:findEntry(binaryName)
			local binaryContents = nil

			if binaryEntry then
				binaryContents = reader:extract(binaryEntry, { type = "binary" }) :: buffer
			else
				-- Walk through the entries to find an executable
				reader:walk(function(entry)
					if binaryEntry then
						return
					end

					if entry.isDirectory then
						return
					end

					local contents = reader:extract(entry, { type = "binary" }) :: buffer
					local executablePlatform = PlatformDescriptor.fromExecutable(contents)

					if executablePlatform:isOk() and eq(executablePlatform:unwrap(), targetPlatform) then
						binaryEntry = entry
						binaryContents = contents
					end
				end)
			end

			if not binaryContents then
				return Result.Err("ExtractBinaryError::BinaryNotFound" :: string)
			end

			return Result.Ok(binaryContents)
		end,

		-- TODO: Other formats
	}

return { extractBinary = extractBinary, detectFormat = detectFormat }
