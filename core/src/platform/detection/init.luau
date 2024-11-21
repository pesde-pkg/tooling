local executable = require("./executable")
export type ExecutableDetectionResult = executable.ExecutableDetectionResult

return {
	detect = require("./pattern"),
	detectFromExecutable = executable,
}
