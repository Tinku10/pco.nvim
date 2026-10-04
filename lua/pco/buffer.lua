local M = {}

local function get_buf_by_path(path)
	local bufs = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(bufs) do
		local buf_path = vim.api.nvim_buf_get_name(bufnr)
		if buf_path == path then
			return bufnr
		end
	end

	local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_name(bufnr, path)

  print("created new buffer " .. bufnr)

	return bufnr
end

function M.apply_changes(ctx, message)
	print("applying change")
	local diffs = message["diffs"]

	for _, diff in pairs(diffs) do
		vim.schedule(function()
			local path = vim.fs.joinpath(ctx.path, diff["path"])
			local bufnr = get_buf_by_path(path)

			for _, line in pairs(diff["lines"]) do
				local clean_line = string.gsub(line.body, "[\r\n]", "")
				local kind = line.kind
				if kind == "DIFF_ADDED" or kind == "DIFF_MODIFIED" then
					vim.schedule(function()
						vim.api.nvim_buf_set_lines(bufnr, line.num, line.num + 1, false, { clean_line })
					end)
				elseif kind == "DIFF_DELETED" then
					vim.schedule(function()
						vim.api.nvim_buf_set_lines(bufnr, line.num, line.num + 1, false, {})
					end)
				end
			end

			-- no state changes yet, user must not have made changes
			if ctx.curr_state[bufnr] == nil then
				vim.api.nvim_set_current_buf(bufnr)
			end

			-- vim.schedule(function()
			ctx.curr_state[bufnr] = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
			-- end)
		end)
	end
end

-- currently the listen only tracks changes on open buffers
--
-- TODO: track changes for the entire share path
-- - 1. when client modifies a file that doesn't have a buffer on server, open a new buffer (lazy)
-- - 2. any node entering a new file (unopened buffer) should send an event to others to open that file in a buffer
-- - 3. file switches can always be sent and the other end can ignore it if a buffer is already open for it (this should not happen with the point above)
---@param ctx pco
---@param buf number
function M.listen_for_buf_change(ctx)
	local function attach(bufnr)
		-- track the user's buffer, buffers will have to move based on file open
		vim.api.nvim_buf_attach(bufnr, false, {
			on_lines = function(_, _, _, first_line, last_line, new_last_line)
				print("sending change")
        local old_state = ctx.curr_state[bufnr] or ""
				local new_state = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
				ctx.api.send_message(ctx.node, old_state, new_state)
				ctx.curr_state[bufnr] = new_state
			end,
		})
	end

	vim.schedule(function()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			attach(bufnr)
		end

    vim.api.nvim_create_autocmd({ "BufAdd", "BufNew" }, {
      callback = function(args)
        attach(args.buf)
      end,
    })
	end)

end

return M
