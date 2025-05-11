local executable = require("./executable")
export type ExecutableDescriptor = executable.ExecutableDescriptor

return {
	detect = require("./pattern"),
	detectFromExecutable = executable,
}
