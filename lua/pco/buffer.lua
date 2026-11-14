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

local function buf_add_blank_lines(bufnr, diff)
  local old_line_count = vim.api.nvim_buf_line_count(bufnr)
  local new_line_count = 0

  for _, line in pairs(diff["lines"]) do
    -- end row is 0 indexed
    if line.range.end_row >= new_line_count then
      new_line_count = line.range.end_row + 1
    end
  end

  local empty_lines = {}
  for _ = old_line_count, new_line_count do
    table.insert(empty_lines, "")
  end

  if new_line_count >= old_line_count then
      vim.api.nvim_buf_set_lines(
          bufnr,
          old_line_count,
          new_line_count,
          false,
          empty_lines
      )
  end
end

function M.apply_changes(ctx, message)
	print("applying change")
  -- vim.print(message)
	-- local diffs = message["diffs"]

  local kind = message["kind"]
  local doc = message["crdt_document"]
  local bufnr = 0 --get_buf_by_path(path)
  local lines = doc["test.txt"] or {}

  vim.schedule(function()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end)

	-- for _, diff in pairs(diffs) do
	-- 	vim.schedule(function()
	-- 		-- local path = vim.fs.joinpath(ctx.path, diff["path"])
	-- 		-- local bufnr = get_buf_by_path(path)
      -- local bufnr = 0

      -- buf_add_blank_lines(bufnr, diff)

	-- 		for _, line in pairs(diff["lines"]) do
	-- 			local kind = line.kind
        -- local range = line.range


        -- if kind == "DIFF_MODIFIED" then
          -- vim.api.nvim_buf_set_text(bufnr, range.start_row, range.start_col, range.end_row, range.end_col, vim.split(line.body, "\n"))
        -- elseif kind == "DIFF_DELETED" then
          -- vim.api.nvim_buf_set_text(bufnr, range.start_row, range.start_col, range.end_row, range.end_col, {})
        -- else
          -- vim.api.nvim_buf_set_text(bufnr, range.start_row, range.start_col, range.start_row, range.start_col, vim.split(line.body, "\n"))
        -- end
	-- 			-- if kind == "DIFF_ADDED" or kind == "DIFF_MODIFIED" then
	-- 			-- 	vim.schedule(function()
	-- 			-- 		vim.api.nvim_buf_set_lines(bufnr, line.num, line.num + 1, false, { clean_line })
	-- 			-- 	end)
	-- 			-- elseif kind == "DIFF_DELETED" then
	-- 			-- 	vim.schedule(function()
	-- 			-- 		vim.api.nvim_buf_set_lines(bufnr, line.num, line.num + 1, false, {})
	-- 			-- 	end)
	-- 			-- end
	-- 		end

	-- 		-- no state changes yet, user must not have made changes
      -- -- if not ctx.is_client_ready then
	-- 			-- vim.api.nvim_set_current_buf(bufnr)
      -- --   ctx.is_client_ready = true
	-- 		-- end

	-- 		-- vim.schedule(function()
      -- ctx.curr_state[bufnr] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- 		-- end)
	-- 	end)
	-- end
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
    -- set the initial state
    ctx.curr_state[bufnr] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		vim.api.nvim_buf_attach(bufnr, false, {
      -- on_bytes = function(_, bufnr, _, start_row, start_col, _, old_end_row, old_end_col, old_end_byte, new_end_row, new_end_col, new_end_byte)
      --   local change_type = nil
      --   if new_end_byte > 0 and old_end_byte == 0 then
      --     change_type = "DIFF_ADDED"
      --   elseif old_end_byte > 0  and new_end_byte == 0 then
      --     change_type = "DIFF_DELETED"
      --   else
      --     change_type = "DIFF_MODIFIED"
      --   end

      --   local path = vim.api.nvim_buf_get_name(bufnr)

      --   new_end_row = new_end_row + start_row
      --   old_end_row = old_end_row + start_row
      --   if new_end_row == 0 then
      --     new_end_col = new_end_col + start_col
      --   end
      --   if old_end_row == 0 then
      --     old_end_col = old_end_col + start_col
      --   end

      --   -- vim.print(start_row, start_col, new_end_row, new_end_col)

      --   local lines = vim.api.nvim_buf_get_text(
      --       bufnr,
      --       start_row,
      --       start_col,
      --       new_end_row,
      --       new_end_col,
      --       {}
      --   )

      --   local content = table.concat(lines, "\n")

      --   print("sending message")

      --   ctx.api.send_message(
      --       ctx.node,
      --       path,
      --       start_row,
      --       start_col,
      --       old_end_row,
      --       old_end_col,
      --       change_type,
      --       content
      --   )
      -- end
			on_lines = function(_, _, _, first_line, last_line, new_last_line, _)
        local changes = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

				print("sending change")
        -- vim.print(ctx.curr_state)
        -- local old_state = ctx.curr_state[bufnr] or {}
				-- local new_state = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local path = "test.txt" -- vim.api.nvim_buf_get_name(bufnr)


        -- local last_line_length = #old_state[last_line]
        -- vim.print(first_line, last_line, new_last_line)

				-- ctx.api.send_message(ctx.node, path, old_state, new_state)
        -- vim.print(changes)
        ctx.api.send_message(ctx.node, path, changes)
        -- ctx.api.send_message(ctx.node, path, first_line, 0, last_line - 1, last_line_length, change_type, table.concat(changes, "\n"))
				-- ctx.curr_state[bufnr] = new_state
			end,
		})
	end

  vim.schedule(function()
    attach(0)
  end)
	-- vim.schedule(function()
	-- 	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      -- if vim.api.nvim_buf_is_loaded(bufnr) then
        -- attach(bufnr)
      -- end
	-- 	end

    -- vim.api.nvim_create_autocmd({ "BufAdd", "BufNew" }, {
      -- callback = function(args)
        -- attach(args.buf)
      -- end,
    -- })
	-- end)

end

return M
