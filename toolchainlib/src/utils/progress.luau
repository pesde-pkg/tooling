--> Inspired by Rokit's progress bar: https://github.com/rojo-rbx/rokit/blob/a303faf/src/util/progress.rs

local task = require("@lune/task")
local stdio = require("@lune/stdio")

local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>

-- FORMAT: {SPINNER} {MESSAGE} {BAR} {STAGE}
local SPINNERS = { "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local BAR_COMPONENT = "▇"
local MAX_BAR_LENGTH = 30

local ProgressBar = {}
type ProgressBar = {
	stages: { { tag: string, message: string } },
	currentStageIndex: number,
	finished: boolean,
	thread: thread?,
}
export type ProgressBarImpl = typeof(setmetatable({} :: ProgressBar, { __index = ProgressBar }))

function ProgressBar.new(): ProgressBarImpl
	return setmetatable(
		{
			stages = {},
			currentStageIndex = 1,
			finished = false,
		} :: ProgressBar,
		{
			__index = ProgressBar,
		}
	)
end

function ProgressBar.withStage(self: ProgressBarImpl, tag: string, msg: string): ProgressBarImpl
	table.insert(self.stages, { tag = tag, message = msg })
	return self
end

function ProgressBar.start(self: ProgressBarImpl): ()
	local BAR_LENGTH = MAX_BAR_LENGTH // #self.stages
	local TOTAL_BAR_LENGTH = BAR_LENGTH * #self.stages
	local BAR = string.rep(BAR_COMPONENT, BAR_LENGTH)
	local MAX_MESSAGE_LENGTH = 0
	for _, stage in self.stages do
		local len = #stage.message
		if len > MAX_MESSAGE_LENGTH then
			MAX_MESSAGE_LENGTH = len
		end
	end

	self.thread = task.spawn(function()
		while not self.finished do
			if self.currentStageIndex == #self.stages then
				self:stop()
				break
			end

			for _, spinner in SPINNERS do
				local stage = self.stages[self.currentStageIndex]
				stdio.write(
					`\x1b[2K\x1b[0G{spinner} {stage.message}{string.rep(" ", MAX_MESSAGE_LENGTH - #stage.message)} [{string.rep(
						BAR,
						self.currentStageIndex
					)}{string.rep(" ", TOTAL_BAR_LENGTH - (BAR_LENGTH * self.currentStageIndex))}] {self.currentStageIndex} / {#self.stages}`
				)

				task.wait(0.1)
			end
		end

		stdio.write("\n")
	end)
end

function ProgressBar.stop(self: ProgressBarImpl): ()
	self.finished = true
end

function ProgressBar.pause(self: ProgressBarImpl): ()
	local _ = self.thread and coroutine.yield(self.thread)
end

function ProgressBar.resume(self: ProgressBarImpl): ()
	local _ = self.thread and coroutine.resume(self.thread)
end

function ProgressBar.nextStage(self: ProgressBarImpl): ()
	local inc = self.currentStageIndex + 1
	if inc > #self.stages then
		-- TODO: Make this a result
		self.finished = true
		return error("Out of stage bounds")
	end

	self.currentStageIndex = inc
end

return ProgressBar
