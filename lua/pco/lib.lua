---@class pco
local M = {}

local lib = package.loadlib("/Users/tinku/Desktop/codes/projects/pco/build/libpco.dylib", "luaopen_mylib")
local api = lib()

function M.client_connect(ip, port)
	M.node = api.client_listen(ip, port)
	print("client connected")
	M.client_get_eventfd()
end

function M.client_hello()
	api.client_hello(M.node)
end

function M.client_get_eventfd()
	local readfd = api.client_get_eventfd(M.node)

	local pipe = vim.uv.new_pipe(false)
	local success, err = vim.uv.pipe_open(pipe, readfd)
	if not success then
		error("failed to read pipe" .. tostring(err))
	end

	pipe:read_start(function(err, chunk)
		if err then
			pipe:read_stop()
			pipe:close()
			return
		end

		if chunk then
			print("new message arrived")
			M.client_get_message()
			return
		end

		print("pipe closed by writer")
		pipe:read_stop()
		pipe:close()
	end)
end

function M.client_get_message()
	print("retrieving message")
	local message = api.client_get_message(M.node)

	M.apply_changes(message)

	if message.kind == "SERVER_HELLO" then
		M.listen_for_buf_change()
	end

	return message
end

function M.apply_changes(message)
	local diffs = message["diffs"]

	for _, diff in pairs(diffs) do
		for _, line in pairs(diff["lines"]) do
			local clean_line = string.gsub(line.body, "[\r\n]", "")
			local kind = line.kind
			if kind == "DIFF_ADDED" or kind == "DIFF_MODIFIED" then
				vim.schedule(function()
					vim.api.nvim_buf_set_lines(0, line.num - 1, line.num - 1, false, { clean_line })
				end)
			elseif kind == "DIFF_DELETED" then
				vim.schedule(function()
					vim.api.nvim_buf_set_lines(0, line.num - 1, line.num - 1, false, {})
				end)
			end
		end
	end

	vim.schedule(function()
		M.curr_state = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	end)
end

function M.listen_for_buf_change()
	vim.schedule(function()
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_attach(buf, false, {
			on_lines = function(_, _, _, first_line, last_line, new_last_line)
				print("sending change")
        new_state = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
				-- print("Buffer changed", M.curr_state, new_state)
				api.client_send_message(M.node, M.curr_state, new_state)
				M.curr_state = new_state
			end,
		})
	end)
end

-- function M.setup_dir(message)
--   local tmp_dir = "/tmp/pco-session"

--   local success, err = lfs.mkdir(tmp_dir)
--   if success then
-- 	for _, diff in pairs(diffs) do
-- 		for _, line in pairs(diff["lines"]) do
--       local path = line.path

--     end
--   end
-- end

return M
