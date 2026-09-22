local pco = require("pco/lib")

local M = {}

function M.setup()
  pco.client_connect("192.168.29.126", 8080)
  pco.client_hello()
end

return M

