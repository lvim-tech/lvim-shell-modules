---@class lvim-shell-modules.lazygit
---@overload fun(opts?: lvim-shell-modules.lazygit.Config): lvim-shell-modules.win
local M = setmetatable({}, {
	__call = function(t, ...)
		return t.open(...)
	end,
})

M.meta = {
	desc = "Open LazyGit in a float, auto-configure colorscheme and integration with Neovim",
}

---@alias lvim-shell-modules.lazygit.Color {fg?:string, bg?:string, bold?:boolean}

---@class lvim-shell-modules.lazygit.Theme: table<number, lvim-shell-modules.lazygit.Color>
---@field activeBorderColor lvim-shell-modules.lazygit.Color
---@field cherryPickedCommitBgColor lvim-shell-modules.lazygit.Color
---@field cherryPickedCommitFgColor lvim-shell-modules.lazygit.Color
---@field defaultFgColor lvim-shell-modules.lazygit.Color
---@field inactiveBorderColor lvim-shell-modules.lazygit.Color
---@field optionsTextColor lvim-shell-modules.lazygit.Color
---@field searchingActiveBorderColor lvim-shell-modules.lazygit.Color
---@field selectedLineBgColor lvim-shell-modules.lazygit.Color
---@field unstagedChangesColor lvim-shell-modules.lazygit.Color

---@class lvim-shell-modules.lazygit.Config: lvim-shell-modules.terminal.Opts
---@field args? string[]
---@field theme? lvim-shell-modules.lazygit.Theme
local defaults = {
	configure = true,
	config = {
		os = { editPreset = "nvim-remote" },
		gui = {
			nerdFontsVersion = "3",
		},
	},
	theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazygit-theme.yml"),
	theme = {
		[241] = { fg = "Special" },
		activeBorderColor = { fg = "MatchParen", bold = true },
		cherryPickedCommitBgColor = { fg = "Identifier" },
		cherryPickedCommitFgColor = { fg = "Function" },
		defaultFgColor = { fg = "Normal" },
		inactiveBorderColor = { fg = "FloatBorder" },
		optionsTextColor = { fg = "Function" },
		searchingActiveBorderColor = { fg = "MatchParen", bold = true },
		selectedLineBgColor = { bg = "Visual" }, -- set to `default` to have no background colour
		unstagedChangesColor = { fg = "DiagnosticError" },
	},
	win = {
		style = "lazygit",
	},
}

LvimShellModules.config.style("lazygit", {})

-- Обновяване на конфиг файла при стартиране
local dirty = true
local config_dir ---@type string?

-- Обновяване на тема файла при промяна на ColorScheme
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		dirty = true
	end,
})

---@param opts lvim-shell-modules.lazygit.Config
local function env(opts)
	if not config_dir then
		local out = vim.fn.system({ "lazygit", "-cd" })
		local lines = vim.split(out, "\n", { plain = true })

		if vim.v.shell_error == 0 and #lines > 1 then
			config_dir = vim.split(lines[1], "\n", { plain = true })[1]

			---@type string[]
			local config_files = vim.tbl_filter(function(v)
				return v:match("%S")
			end, vim.split(vim.env.LG_CONFIG_FILE or "", ",", { plain = true }))

			if #config_files == 0 then
				config_files[1] = vim.fs.normalize(config_dir .. "/config.yml")
			end

			if not vim.tbl_contains(config_files, opts.theme_path) then
				table.insert(config_files, opts.theme_path)
			end

			vim.env.LG_CONFIG_FILE = table.concat(config_files, ",")
		end
	end
end

---@param v lvim-shell-modules.lazygit.Color
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

---@param opts lvim-shell-modules.lazygit.Config
local function update_config(opts)
	---@type table<string, string[]>
	local theme = {}

	for k, v in pairs(opts.theme) do
		if type(k) == "number" then
			local color = get_color(v)
			pcall(io.write, ("\27]4;%d;%s\7"):format(k, color[1]))
		else
			theme[k] = get_color(v)
		end
	end

	local config = vim.tbl_deep_extend("force", { gui = { theme = theme, border = "hidden" } }, opts.config or {})

	-- Остатъкът от функцията остава същия
	local function yaml_val(val)
		if type(val) == "boolean" then
			return tostring(val)
		end
		return type(val) == "string" and not val:find("^\"'`") and ("%q"):format(val) or val
	end

	local function to_yaml(tbl, indent)
		indent = indent or 0
		local lines = {}
		for k, v in pairs(tbl) do
			table.insert(lines, string.rep(" ", indent) .. k .. (type(v) == "table" and ":" or ": " .. yaml_val(v)))
			if type(v) == "table" then
				if (vim.islist or vim.tbl_islist)(v) then
					for _, item in ipairs(v) do
						table.insert(lines, string.rep(" ", indent + 2) .. "- " .. yaml_val(item))
					end
				else
					vim.list_extend(lines, to_yaml(v, indent + 2))
				end
			end
		end
		return lines
	end
	vim.fn.writefile(to_yaml(config), opts.theme_path)
	dirty = false
end

---@param opts? lvim-shell-modules.lazygit.Config
function M.open(opts)
	---@type lvim-shell-modules.lazygit.Config
	opts = LvimShellModules.config.get("lazygit", defaults, opts)

	-- Установяваме работната директория
	opts.cwd = opts.cwd or vim.fn.getcwd()

	local cmd = { "lazygit" }
	if opts.args then
		vim.list_extend(cmd, opts.args)
	end

	-- Ако не сме в git repo, просто отваряме lazygit без допълнителни аргументи
	-- Това ще покаже менюто за избор на репо
	if vim.fn.finddir(".git", opts.cwd) == "" and vim.fn.findfile(".git", opts.cwd) == "" then
		opts.cwd = vim.fn.expand("$HOME") -- Връщаме се в home директорията
	end

	if opts.configure then
		if dirty then
			update_config(opts)
		end
		env(opts)
	end

	return LvimShellModules.terminal(cmd, opts)
end

---@param repo string
---@param opts? lvim-shell-modules.lazygit.Config
function M.repo(repo, opts)
	opts = opts or {}
	opts.cwd = repo
	return M.open(opts)
end

---@param branch? string
---@param opts? lvim-shell-modules.lazygit.Config
function M.branch(branch, opts)
	opts = opts or {}
	if branch then
		opts.args = opts.args or {}
		table.insert(opts.args, "--filter-by-branch")
		table.insert(opts.args, branch)
	end
	return M.open(opts)
end

---@param opts? lvim-shell-modules.lazygit.Config
function M.log(opts)
	opts = opts or {}
	opts.args = opts.args or { "log" }
	return M.open(opts)
end

---@param opts? lvim-shell-modules.lazygit.Config
function M.log_file(opts)
	local file = vim.trim(vim.api.nvim_buf_get_name(0))
	opts = opts or {}
	opts.args = { "-f", file }
	opts.cwd = vim.fn.fnamemodify(file, ":h")
	return M.open(opts)
end

return M
