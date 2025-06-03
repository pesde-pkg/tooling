local executable = require("@self/executable")
export type ExecutableDetectionResult = executable.ExecutableDetectionResult

return {
	detect = require("@self/pattern"),
	detectFromExecutable = executable,
}
