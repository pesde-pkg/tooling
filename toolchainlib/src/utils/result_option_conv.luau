--> Non-exhaustive set of extensions for Option<->Result conversion

local OptionImpl = require("../../lune_packages/option")
local ResultImpl = require("../../lune_packages/result")

local Option = {}
local Result = {}

export type Option<T> = OptionImpl.Option<T> & typeof(Option)
export type Result<T, E> = ResultImpl.Result<T, E> & typeof(Result)

function Option.okOr<T, E>(self: Option<T>, err: E): Result<T, E>
	return self:mapOrElse(function()
		return ResultImpl.Err(err)
	end, function(val)
		return ResultImpl.Ok(val)
	end) :: Result<T, E>
end

function Result.ok<T, E>(self: Result<T, E>): Option<T>
	return self:mapOr(OptionImpl.None, function(val: T)
		return OptionImpl.Some(val)
	end) :: Option<T>
end

return {
	Option = setmetatable(OptionImpl, {
		__index = Option,
	}),

	Result = setmetatable(ResultImpl, {
		__index = Result,
	}),
}
