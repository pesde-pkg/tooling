local process = require("@lune/process")

type Arch = process.Arch | "arm" | "x86"
export type ExecutableDetectionResult = {
	os: process.OS?,
	arch: Arch?,
}

return function(binaryContents: buffer): ExecutableDetectionResult?
	-- Windows PE
	do
		local DOS_HEADER = "MZ"
		local PE_HEADER_OFFSET = 0x3c
		local PE_MAGIC_SIGNATURE = "PE\x00\x00"
		local PE_MACHINE_TYPES: { [number]: Arch } = {
			[0x8664] = "x86_64",
			[0x01c0] = "arm",
			[0xaa64] = "aarch64",
			[0x014c] = "x86",
		}

		if buffer.readstring(binaryContents, 0, 2) == DOS_HEADER then
			-- File was a DOS executable, jump to PE header to get the magic offset
			local signatureOffset = buffer.readu8(binaryContents, PE_HEADER_OFFSET)

			-- Check if the value at the magic offset was the PE magic signature
			if buffer.readstring(binaryContents, signatureOffset, 4) == PE_MAGIC_SIGNATURE then
				-- After the first 4 magic bytes, the next 2 bytes are architecture information
				local machineType = buffer.readu16(binaryContents, signatureOffset + 4)
				return {
					os = "windows",
					arch = PE_MACHINE_TYPES[machineType],
				}
			end
		end
	end

	-- Linux ELF
	do
		local ELF_MAGIC_START = 0x7f
		local ELF_MAGIC_SIGNATURE = "ELF"
		local ELF_MACHINE_TYPES: { [number]: Arch } = {
			[0x3e] = "x86_64",
			[0x28] = "arm",
			[0xb7] = "aarch64",
			[0x03] = "x86",
		}

		-- ELF files have a magic signature of [0x7f, 'E', 'L', 'F']
		if
			buffer.readu8(binaryContents, 0) == ELF_MAGIC_START
			and buffer.readstring(binaryContents, 1, 3) == ELF_MAGIC_SIGNATURE
		then
			-- Machine type is located after 16 bytes of ident and 2 bytes of type
			local machineType = buffer.readu16(binaryContents, 18)
			return {
				os = "linux",
				arch = ELF_MACHINE_TYPES[machineType],
			}
		end
	end

	-- macOS Mach-O
	do
		local MACHO_MAGIC_32 = 0xFEEDFACE
		local MACHO_MAGIC_64 = 0xFEEDFACF
		local MACHO_CPU_TYPES = {
			x86 = 0x7,
			arm = 0xc,
		}

		-- First 4 bytes are the magic depending on 32 or 64 bit
		-- Next 2 bytes are the CPU type
		local headerStart = buffer.readu32(binaryContents, 0)
		local cpuType = buffer.readu16(binaryContents, 4)

		local is64bit = headerStart == MACHO_MAGIC_64
		local is32bit = headerStart == MACHO_MAGIC_32

		return {
			os = "macos",
            --stylua: ignore
			arch = (
                if is64bit and cpuType == MACHO_CPU_TYPES.x86 then "x86_64"
				elseif is64bit and cpuType == MACHO_CPU_TYPES.arm then "aarch64"
				elseif is32bit and cpuType == MACHO_CPU_TYPES.x86 then "x86"
				elseif is32bit and cpuType == MACHO_CPU_TYPES.arm then "arm"
				else nil
            ),
		}
	end
end
