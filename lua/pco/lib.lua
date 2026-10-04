local lib = package.loadlib("/Users/tinku/Desktop/codes/projects/pco/build/libpco.dylib", "luaopen_mylib")
local buf = require("pco.buffer")

---@class pco
---@field node table
---@field path string
---@field api table
local M = {
  api = lib(),
  -- mapping bufnr to the current content for each buffer
  curr_state = {}
}

--@return string
local function setup_dir()
  local tmp_dir = "/tmp/pco-session"
  vim.fn.mkdir(tmp_dir, "p")
  return tmp_dir
end

---@return table
local function get_message()
	return M.api.get_message(M.node)
end

local function get_eventfd()
	print("getting read end of the pipe")
	local readfd = M.api.get_eventfd(M.node)

	local pipe = vim.uv.new_pipe(false)
	local success, err = vim.uv.pipe_open(pipe, readfd)
	if not success then
		error("failed to read pipe" .. tostring(err))
	end

	print("pipe connected")

	pipe:read_start(function(err, chunk)
		if err then
			print("error during read")
			pipe:read_stop()
			-- pipe:close()
			return
		end

		if chunk then
			repeat
				local message = get_message()
				if not message then
					break
				end
				buf.apply_changes(M, message)

				if message.kind == "CLIENT_HELLO" then
					buf.listen_for_buf_change(M)
				end

			until false

			return
		end

		print("pipe closed by writer")
		pipe:read_stop()
		-- pipe:close()
	end)
end

function M.client_connect(ip, port)
  -- path points to a unique session directory under /tmp
  M.path = setup_dir()
	M.node = M.api.client_listen(ip, port)
	M.api.client_hello(M.node)
	get_eventfd()
end

function M.server_start(port, path)
  -- path points to the shared path (usually CWD or file)
	M.path = path
	M.node = M.api.server_start(port, path)
	get_eventfd()
end

return M
