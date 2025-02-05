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

---@meta

---@class lvim-shell-modules.terminal.Opts
---@field on_exit? fun(code: number)
---@field on_stdout? fun(data: string[])
---@field on_stderr? fun(data: string[])

---@alias lvim-shell-modules.neomutt.Color {fg?:string, bg?:string, bold?:boolean}
---@alias lvim-shell-modules.neomutt.Account {name:string, email:string, from:string, smtp:string, imap:string}

---@class lvim-shell-modules.neomutt.IndexFlags
---@field new? lvim-shell-modules.neomutt.Color
---@field deleted? lvim-shell-modules.neomutt.Color
---@field flagged? lvim-shell-modules.neomutt.Color
---@field tagged? lvim-shell-modules.neomutt.Color
---@field important? lvim-shell-modules.neomutt.Color

---@class lvim-shell-modules.neomutt.Theme
---@field attachment? lvim-shell-modules.neomutt.Color
---@field body? lvim-shell-modules.neomutt.Color
---@field bold? lvim-shell-modules.neomutt.Color
---@field error? lvim-shell-modules.neomutt.Color
---@field header? lvim-shell-modules.neomutt.Color
---@field hdrdefault? lvim-shell-modules.neomutt.Color
---@field indicator? lvim-shell-modules.neomutt.Color
---@field markers? lvim-shell-modules.neomutt.Color
---@field message? lvim-shell-modules.neomutt.Color
---@field normal? lvim-shell-modules.neomutt.Color
---@field quoted? lvim-shell-modules.neomutt.Color
---@field search? lvim-shell-modules.neomutt.Color
---@field signature? lvim-shell-modules.neomutt.Color
---@field status? lvim-shell-modules.neomutt.Color
---@field tilde? lvim-shell-modules.neomutt.Color
---@field tree? lvim-shell-modules.neomutt.Color
---@field underline? lvim-shell-modules.neomutt.Color
---@field index_flags? lvim-shell-modules.neomutt.IndexFlags
---@field body_time? lvim-shell-modules.neomutt.Color
---@field body_date? lvim-shell-modules.neomutt.Color
---@field body_emphasis? lvim-shell-modules.neomutt.Color
---@field body_strong? lvim-shell-modules.neomutt.Color
---@field header_from? lvim-shell-modules.neomutt.Color
---@field header_subject? lvim-shell-modules.neomutt.Color
---@field header_user_agent? lvim-shell-modules.neomutt.Color

---@class lvim-shell-modules.neomutt.Config: lvim-shell-modules.terminal.Opts
---@field theme? lvim-shell-modules.neomutt.Theme
---@field config? table
---@field theme_path? string
---@field configure? boolean
---@field accounts? lvim-shell-modules.neomutt.Account[]

---@class LvimShellModules
---@field config {get: fun(name: string, defaults: lvim-shell-modules.neomutt.Config, opts?: lvim-shell-modules.neomutt.Config): lvim-shell-modules.neomutt.Config}
---@field terminal fun(cmd: string[], opts?: lvim-shell-modules.terminal.Opts): lvim-shell-modules.win
local defaults = {
	configure = true,
	theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/neomutt-theme"),
	theme = {
		colors = {
			normal = { fg = "DiagnosticError" },
			indicator = { fg = "Black", bg = "Normal" },
			tree = { fg = "Directory" },
			error = { fg = "DiagnosticError" },
			tilde = { fg = "DiagnosticError" },
			message = { fg = "String" },
			markers = { fg = "DiagnosticError" },
			attachment = { fg = "Normal" },
			search = { fg = "DiagnosticError" },
			status = { fg = "Type" },
			hdrdefault = { fg = "Comment" },
		},
		quoted = {
			quoted = { fg = "String" },
			quoted1 = { fg = "Function" },
			quoted2 = { fg = "String" },
			quoted3 = { fg = "Function" },
			quoted4 = { fg = "String" },
			quoted5 = { fg = "Function" },
			signature = { fg = "Function" },
			bold = { fg = "Comment" },
			underline = { fg = "Comment" },
		},
		mono = {
			{ name = "bold", style = "bold" },
			{ name = "underline", style = "underline" },
			{ name = "indicator", style = "reverse" },
			{ name = "error", style = "bold" },
		},
		header = { fg = "Directory" },
		index = {
			{ pattern = "~Q", hl = { fg = "Directory" } },
			{ pattern = "~D", hl = { fg = "DiagnosticError" } },
			{ pattern = "~O", hl = { fg = "Directory" } },
			{ pattern = "~P", hl = { fg = "Directory" } },
			{ pattern = "~T", hl = { fg = "Directory" } },
			{ pattern = "~F", hl = { fg = "DiagnosticError" } },
			{ pattern = "~v", hl = { fg = "Directory" } },
			{ pattern = "~k", hl = { fg = "DiagnosticError" } },
			{ pattern = "~N", hl = { fg = "String" } },
		},
		index_author = { fg = "Directory" },
	},
	win = {
		style = "neomutt",
	},
}

LvimShellModules.config.style("neomutt", {})

-- Обновяване на конфиг файла при стартиране
local dirty = true

-- Обновяване на theme файла при промяна на цветовата схема
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		dirty = true
	end,
})

---@param v lvim-shell-modules.neomutt.Color
---@return string[]
local function get_color(v)
	---@type string[]
	local color = {}
	for _, c in ipairs({ "fg", "bg" }) do
		if v[c] then
			local name = v[c]
			local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
			local hl_color ---@type number?
			if c == "fg" then
				hl_color = hl and hl.fg or hl.foreground
			else
				hl_color = hl and hl.bg or hl.background
			end
			if hl_color then
				table.insert(color, string.format("#%06x", hl_color))
			end
		end
	end
	if v.bold then
		table.insert(color, "bold")
	end
	return color
end

---@param opts lvim-shell-modules.neomutt.Config
local function update_config(opts)
	local current_time = "2025-02-02 20:27:21" -- UTC формат
	local username = "bojanbb"

	-- Създаваме таблица за цветовете
	---@type table<string, string[]>
	local theme = {}

	-- Първо конвертираме всички цветове
	for group_name, group_colors in pairs(opts.theme.colors) do
		theme[group_name] = get_color(group_colors)
	end

	for quote_name, quote_colors in pairs(opts.theme.quoted) do
		theme[quote_name] = get_color(quote_colors)
	end

	local lines = {
		"# neomutt color theme",
		string.format("# Generated for user: %s", username),
		string.format("# Generated at: %s UTC", current_time),
		"",
	}

	-- Основни цветове във фиксиран ред
	local basic_order = {
		"normal",
		"indicator",
		"tree",
		"error",
		"tilde",
		"message",
		"markers",
		"attachment",
		"search",
		"status",
		"hdrdefault",
	}

	for _, name in ipairs(basic_order) do
		if theme[name] and #theme[name] > 0 then
			table.insert(
				lines,
				string.format("color %-24s %-15s %s", name, theme[name][1], theme[name][2] or "default")
			)
		end
	end

	-- Quoted цветове във фиксиран ред
	local quoted_order = {
		"quoted",
		"quoted1",
		"quoted2",
		"quoted3",
		"quoted4",
		"quoted5",
		"signature",
		"bold",
		"underline",
	}

	for _, name in ipairs(quoted_order) do
		if theme[name] and #theme[name] > 0 then
			table.insert(
				lines,
				string.format("color %-24s %-15s %s", name, theme[name][1], theme[name][2] or "default")
			)
		end
	end

	-- Mono стилове
	for _, mono in ipairs(opts.theme.mono) do
		table.insert(lines, string.format("mono %-28s %s", mono.name, mono.style))
	end

	table.insert(lines, "")
	table.insert(lines, "")

	-- Header
	local header_colors = get_color(opts.theme.header)
	if #header_colors > 0 then
		table.insert(lines, string.format("color header     %-15s %-10s %s", header_colors[1], "default", "."))
	end

	-- Index цветове
	for _, index in ipairs(opts.theme.index) do
		local colors = get_color(index.hl)
		if #colors > 0 then
			table.insert(
				lines,
				string.format("color %-10s %-15s %-10s %s", "index", colors[1], "default", index.pattern)
			)
		end
	end

	-- Index author
	local author_colors = get_color(opts.theme.index_author)
	if #author_colors > 0 then
		table.insert(
			lines,
			string.format("color %-10s %-15s %-10s %s", "index_author", author_colors[1], "default", ".*")
		)
	end

	-- Записваме конфигурацията
	-- vim.fn.writefile(lines, opts.theme_path, "b")
end

---@param opts? lvim-shell-modules.neomutt.Config
function M.open(opts)
	---@type lvim-shell-modules.neomutt.Config
	opts = LvimShellModules.config.get("neomutt", defaults, opts)

	local cmd = { "neomutt" }

	-- Първо обновяваме темата ако е нужно
	if opts.configure and dirty then
		update_config(opts)
	end

	-- Създаваме временен конфигурационен файл който включва
	-- потребителския конфиг и нашата тема
	if opts.configure then
		local temp_config = vim.fn.tempname()
		local lines = {
			'source "/home/biserstoilov/mails/mutt/settings"',
			-- Първо зареждаме потребителската конфигурация
			-- "set color_directcolor = yes",
			'source "'
				.. (opts.muttrc or vim.fn.expand("~/.muttrc"))
				.. '"',
			-- После зареждаме нашата тема
			'source "'
				.. opts.theme_path
				.. '"',
		}
		vim.fn.writefile(lines, temp_config)

		table.insert(cmd, "-F")
		table.insert(cmd, temp_config)
	elseif opts.muttrc and vim.fn.filereadable(opts.muttrc) == 1 then
		-- Ако имаме специфичен muttrc и не искаме да конфигурираме тема
		table.insert(cmd, "-F")
		table.insert(cmd, opts.muttrc)
	end

	vim.list_extend(cmd, opts.args or {})

	-- Интеграция с nvim
	local env = {
		EDITOR = "nvim",
		VISUAL = "nvim",
		NEOMUTT_EDITOR = "nvim",
		TERM = "xterm-direct",
	}
	opts.env = vim.tbl_extend("force", env, opts.env or {})

	return LvimShellModules.terminal(cmd, opts)
end

---@param account string
---@param opts? lvim-shell-modules.neomutt.Config
function M.account(account, opts)
	opts = opts or {}
	if opts.accounts then
		for _, acc in ipairs(opts.accounts) do
			if acc.name == account then
				opts.args = opts.args or {}
				table.insert(opts.args, "-F")
				table.insert(opts.args, opts.theme_path)
				return M.open(opts)
			end
		end
	end
	vim.notify("Account " .. account .. " not found", vim.log.levels.ERROR)
	return nil
end

---@param mailbox string
---@param opts? lvim-shell-modules.neomutt.Config
function M.mailbox(mailbox, opts)
	opts = opts or {}
	opts.args = opts.args or { "-f", mailbox }
	return M.open(opts)
end

---@param to? string
---@param opts? lvim-shell-modules.neomutt.Config
function M.compose(to, opts)
	opts = opts or {}
	opts.args = to and { "-s", "", "--", to } or {}
	return M.open(opts)
end

return M
