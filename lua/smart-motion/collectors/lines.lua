local exit = require("smart-motion.core.events.exit")
local consts = require("smart-motion.consts")
local log = require("smart-motion.core.log")

local EXIT_TYPE = consts.EXIT_TYPE

---@class SmartMotionLineData
---@field line_number integer
---@field text string

---@type SmartMotionCollectorModuleEntry
local M = {}

--- Collects lines from buffer based on motion direction.
--- @return thread A coroutine generator yielding SmartMotionLineData objects
function M.run()
	return coroutine.create(function(ctx, cfg, motion_state)
		exit.throw_if(not vim.api.nvim_buf_is_valid(ctx.bufnr), EXIT_TYPE.EARLY_EXIT)

		local cursor_line = ctx.cursor_line
		local total_lines = vim.api.nvim_buf_line_count(ctx.bufnr)
		local window_size = motion_state.max_lines or 100

		local start_line = math.max(0, cursor_line - window_size)
		local end_line = math.min(total_lines - 1, cursor_line + window_size)

		local line_number = start_line
		while line_number <= end_line do
			-- Skip lines inside closed folds to match Neovim's native j/k behavior
			-- where a fold counts as a single line
			-- foldclosed() returns -1 if line is not in a fold, otherwise returns the first line of the fold
			local fold_start = vim.fn.foldclosed(line_number + 1)
			if fold_start ~= -1 then
				-- Line is inside a closed fold, skip to the end of the fold
				local fold_end = vim.fn.foldclosedend(line_number + 1)
				line_number = fold_end  -- Skip to end of fold (1-based), will be converted back to 0-based
			else
				-- Line is visible (not in a closed fold), collect it
				local line = vim.api.nvim_buf_get_lines(ctx.bufnr, line_number, line_number + 1, false)[1]

				if line then
					coroutine.yield({
						line_number = line_number,
						text = line,
					})
				end
				line_number = line_number + 1
			end
		end
	end)
end

M.metadata = {
	label = "Line Collector",
	description = "Collects full lines forward or backward from the cursor",
}

return M
