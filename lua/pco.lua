local pco = require("pco/lib")

local M = {}

function split(inputstr, sep)
	if sep == nil then
		return inputstr
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.client_connect()
	local host = "192.168.29.127"
	local port = 8080

	vim.ui.input({ prompt = "enter the remote address: " }, function(input)
		if input ~= nil and input ~= "" then
			local parts = vim.split(input, ":", { plain = true })

			host = parts[1]
			port = tonumber(parts[2])
		end

    vim.notify("using inputs: " .. " host=" .. host .. " port=" .. tostring(port))

		pco.client_connect(host, port)
	end)
end

function M.server_start()
	vim.ui.input({ prompt = "enter the relative share path: " }, function(input)
		if input == nil then
			return
		end

    -- input = vim.fs.joinpath(vim.fn.getcwd(), input)

		pco.server_start(8080, input)
	end)
end

return M
