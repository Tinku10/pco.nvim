vim.api.nvim_create_user_command("PcoJoin", require("pco").client_connect, {})
vim.api.nvim_create_user_command("PcoOpen", require("pco").server_start, {})
