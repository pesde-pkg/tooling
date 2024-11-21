local types = require("../utils/result_option_conv")
type Result<T, E> = types.Result<T, E>

export type PlatformError = "NoPatternDetected" | "NoExecutableDetected" | "UnknownExecutableField"
export type PlatformResult<T> = Result<T, PlatformError>

return "<PlatformResult>"
