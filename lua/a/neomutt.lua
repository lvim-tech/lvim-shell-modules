---@class lvim-shell-modules.neomutt
---@overload fun(opts?: lvim-shell-modules.neomutt.Config): lvim-shell-modules.win
local M = setmetatable({}, {
	__call = function(t, ...)
		return t.open(...)
	end,
})

M.meta = {
	desc = "Open Neomutt in a float, using user's mail configuration",
}

---@class lvim-shell-modules.neomutt.Config: lvim-shell-modules.terminal.Opts
---@field args? string[]
---@field muttrc? string
local defaults = {
	win = {
		style = "neomutt",
	},
	muttrc = vim.fn.expand("~/.muttrc"),
}

LvimShellModules.config.style("neomutt", {})

---@param opts? lvim-shell-modules.neomutt.Config
function M.open(opts)
	---@type lvim-shell-modules.neomutt.Config
	opts = LvimShellModules.config.get("neomutt", defaults, opts)

	local cmd = { "neomutt" }

	if opts.muttrc and vim.fn.filereadable(opts.muttrc) == 1 then
		table.insert(cmd, "-F")
		table.insert(cmd, opts.muttrc)
	end

	vim.list_extend(cmd, opts.args or {})

	return LvimShellModules.terminal(cmd, opts)
end

---@param mailbox string
---@param opts? lvim-shell-modules.neomutt.Config
function M.mailbox(mailbox, opts)
	opts = opts or {}
	opts.args = opts.args or { "-f", mailbox }
	return M.open(opts)
end

-- Отваря neomutt за съставяне на ново писмо
---@param to? string
---@param opts? lvim-shell-modules.neomutt.Config
function M.compose(to, opts)
	opts = opts or {}
	opts.args = to and { "-s", "", "--", to } or {}
	return M.open(opts)
end

return M
