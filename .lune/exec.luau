--> lib: Builder pattern class to spawn child processes

local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Option = require("../lune_packages/option")
type Option<T> = Option.Option<T>

local CommandBuilder = {}

export type CommandBuilder = typeof(setmetatable({} :: CommandBuilderFields, { __index = CommandBuilder }))
type CommandBuilderFields = {
	program: string,
	args: { string },
	env: { [string]: string },
	stdioStrategy: Option<IoStrategyMapping>,
}
export type StdioStrategy = "pipe" | "forward" | "none"
export type IoStrategyMapping = {
	stdout: Option<StdioStrategy>,
	stderr: Option<StdioStrategy>,
}

local DEFAULT_STDIO_STRATEGY: IoStrategyMapping = {
	stdout = Option.Some("pipe" :: StdioStrategy),
	stderr = Option.Some("pipe" :: StdioStrategy),
}
function CommandBuilder.new(program: string)
	return setmetatable(
		{
			program = program,
			args = {},
			env = {},
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

function CommandBuilder.withEnvVar(self: CommandBuilder, var: string, value: string): CommandBuilder
	self.env[var] = value
	return self
end

function CommandBuilder.withEnv(self: CommandBuilder, env: { [string]: string }): CommandBuilder
	for var, value in env do
		self:withEnvVar(var, value)
	end

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

function CommandBuilder.exec(self: CommandBuilder): process.SpawnResult
	print(
		stdio.style("bold") .. "$",
		stdio.style("dim") .. self.program,
		table.concat(self.args, " ") .. stdio.style("reset")
	)
	local child = process.spawn(self.program, self.args, {
		shell = if process.os == "windows" then "cmd.exe" else "bash",
		stdio = self.stdioStrategy
			:orOpt(Option.Some(DEFAULT_STDIO_STRATEGY))
			:map(function(mappings: IoStrategyMapping)
				local translatedMappings: process.SpawnOptionsStdio = {}
				for field, value in mappings do
					translatedMappings[field] = intoSpawnOptionsStdioKind((value :: Option<StdioStrategy>):unwrap())
				end

				return translatedMappings
			end)
			:unwrap(),
	})

	if not child.ok then
		print(`\n{stdio.color("red")}[luau-lsp]{stdio.color("reset")} Exited with code`, child.code)
	end

	return child
end

return CommandBuilder
