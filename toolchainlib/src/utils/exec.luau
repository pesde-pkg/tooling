--> Builder pattern class to spawn, manage and kill child processes

local process = require("@lune/process")
local task = require("@lune/task")

local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>

local CommandBuilder = {}
type CommandBuilderFields = {
	program: string,
	args: { string },
	retries: Option<number>,
	ignoreErrors: Option<boolean>,
	stdioStrategy: Option<IoStrategyMapping>,
}
export type CommandBuilder = typeof(setmetatable({} :: CommandBuilderFields, { __index = CommandBuilder }))
export type StdioStrategy = "pipe" | "forward" | "none"
export type IoStrategyMapping = {
	stdout: Option<StdioStrategy>,
	stderr: Option<StdioStrategy>,
}
export type ChildProcess = {
	_thread: thread,
	_pid: string,
	_status: ChildStatus,
	start: (self: ChildProcess) -> (),
	waitForChild: (self: ChildProcess) -> ChildStatus,
	kill: (self: ChildProcess) -> (),
}
export type ChildStatus = { ok: boolean, code: number, io: {
	stdout: string,
	stderr: string,
} }

local DEFAULT_STDIO_STRATEGY: IoStrategyMapping = {
	stdout = Option.Some("pipe" :: StdioStrategy),
	stderr = Option.Some("pipe" :: StdioStrategy),
}
local DEFAULT_RETRIES = 0
local DEFAULT_IGNORE_ERRORS = false

function CommandBuilder.new(program: string)
	return setmetatable(
		{
			program = program,
			args = {},
			retries = Option.None,
			ignoreErrors = Option.None,
			stdioStrategy = Option.None :: Option<IoStrategyMapping>,
		} :: CommandBuilderFields,
		{
			__index = CommandBuilder,
		}
	)
end

function CommandBuilder.withArg(self: CommandBuilder, arg: string): CommandBuilder
	table.insert(self.args, arg)
	return self
end

function CommandBuilder.withArgs(self: CommandBuilder, args: { string }): CommandBuilder
	for _, arg in args do
		self:withArg(arg)
	end

	return self
end

function CommandBuilder.withMaxRetries(self: CommandBuilder, retries: number): CommandBuilder
	self.retries = Option.Some(retries) :: Option<number>
	return self
end

function CommandBuilder.withIgnoreErrors(self: CommandBuilder, yes: boolean): CommandBuilder
	self.ignoreErrors = Option.Some(yes) :: Option<boolean>
	return self
end

function CommandBuilder.withStdioStrategy(
	self: CommandBuilder,
	strategy: StdioStrategy | IoStrategyMapping
): CommandBuilder
	self.stdioStrategy = Option.Some(if typeof(strategy) == "string"
		then {
			stdout = Option.Some(strategy),
			stderr = Option.Some(strategy),
		}
		else strategy) :: Option<IoStrategyMapping>
	return self
end

local function intoSpawnOptionsStdioKind(strategy: StdioStrategy): process.SpawnOptionsStdioKind
	if strategy == "pipe" then
		return "default"
	end

	if strategy == "forward" then
		return "forward"
	end

	if strategy == "none" then
		return "none"
	end

	error(`Non-strategy provided: {strategy}`)
end

function CommandBuilder.intoChildProcess(self: CommandBuilder): ChildProcess
	local child = {
		_thread = coroutine.create(function(this: ChildProcess)
			local retries = self.retries:unwrapOr(DEFAULT_RETRIES)
			local ignoreErrors = self.ignoreErrors:unwrapOr(DEFAULT_IGNORE_ERRORS)
			local argsList = table.concat(self.args, " ")

			for _ = 0, retries do
				local spawned = process.spawn(
					if process.os == "windows"
						then `(Start-Process {self.program} -Passthru -Wait -NoNewWindow -ArgumentList \"{argsList}\").Id`
						else `{self.program} {argsList} & echo $!`,
					{},
					{
						stdio = self.stdioStrategy
							:orOpt(Option.Some(DEFAULT_STDIO_STRATEGY))
							:map(function(mappings: IoStrategyMapping)
								local translatedMappings: process.SpawnOptionsStdio = {}
								for field, value in mappings do
									translatedMappings[field] =
										intoSpawnOptionsStdioKind((value :: Option<StdioStrategy>):unwrap())
								end

								return translatedMappings
							end)
							:unwrap(),
						shell = true,
					}
				)

				if spawned.ok then
					local lines = spawned.stdout:split("\n")

					-- TODO: Abstract upvalues here into a channels primitive
					this._pid = assert(table.remove(lines, 1), "Failed to get PID")
					this._status = {
						code = spawned.code,
						ok = spawned.code == 0 and not ignoreErrors,
						io = {
							stdout = table.concat(lines, "\n"),
							stderr = spawned.stderr,
						},
					}
					break
				end
			end
		end),

		start = function(self: ChildProcess)
			coroutine.resume(self._thread, self)
		end,

		waitForChild = function(self: ChildProcess): ChildStatus
			while coroutine.status(self._thread) ~= "dead" or self._status == nil do
				task.wait(0.1)
			end

			return self._status
		end,

		kill = function(self: ChildProcess)
			coroutine.close(self._thread)
			local killResult = process.spawn(
				if process.os == "windows" then `Stop-Process -Id {self._pid} -Force` else `kill {self._pid}`,
				{
					shell = true,
				}
			)

			assert(killResult.ok, `Failed to kill process with PID {self._pid}`)
		end,
	} :: ChildProcess

	return child
end

return CommandBuilder
