---@class lvim-shell-modules.terminal: lvim-shell-modules.win
---@field cmd? string | string[]
---@field opts lvim-shell-modules.terminal.Opts
---@overload fun(cmd?: string|string[], opts?: lvim-shell-modules.terminal.Opts): lvim-shell-modules.terminal
local M = setmetatable({}, {
	__call = function(t, ...)
		return t.toggle(...)
	end,
})

M.meta = {
	desc = "Create and toggle floating/split terminals",
}

---@class lvim-shell-modules.terminal.Config
---@field win? lvim-shell-modules.win.Config|{}
---@field shell? string|string[] The shell to use. Defaults to `vim.o.shell`
---@field override? fun(cmd?: string|string[], opts?: lvim-shell-modules.terminal.Opts) Use this to use a different terminal implementation
local defaults = {
	win = { style = "terminal" },
}

---@class lvim-shell-modules.terminal.Opts: lvim-shell-modules.terminal.Config
---@field cwd? string
---@field env? table<string, string>
---@field interactive? boolean

LvimShellModules.config.style("terminal", {
	bo = {
		filetype = "lvim_shell_terminal",
	},
	wo = {},
	keys = {
		q = "hide",
		gf = function(self)
			local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
			if f == "" then
				vim.notify("No file under cursor", vim.log.levels.WARN, {
					title = "LVIM Shell Modules",
				})
			else
				self:hide()
				vim.schedule(function()
					vim.cmd("e " .. f)
				end)
			end
		end,
		term_normal = {
			"<esc>",
			function(self)
				self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
				if self.esc_timer:is_active() then
					self.esc_timer:stop()
					vim.cmd("stopinsert")
				else
					self.esc_timer:start(200, 0, function() end)
					return "<esc>"
				end
			end,
			mode = "t",
			expr = true,
			desc = "Double escape to normal mode",
		},
	},
})

---@type table<string, lvim-shell-modules.win>
local terminals = {}

--- Open a new terminal window.
---@param cmd? string | string[]
---@param opts? lvim-shell-modules.terminal.Opts
function M.open(cmd, opts)
	local id = vim.v.count1
	opts = LvimShellModules.config.get("terminal", defaults --[[@as lvim-shell-modules.terminal.Opts]], opts)
	opts.win = LvimShellModules.win.resolve("terminal", {
		position = cmd and "float" or "bottom",
	}, opts.win)
	opts.win.wo.winbar = opts.win.wo.winbar or (opts.win.position == "float" and "" or (id .. ": %{b:term_title}"))

	if opts.override then
		return opts.override(cmd, opts)
	end

	local on_buf = opts.win and opts.win.on_buf

	---@param self lvim-shell-modules.terminal
	opts.win.on_buf = function(self)
		self.cmd = cmd
		vim.b[self.buf].lvim_shell_terminal = { cmd = cmd, id = id }
		if on_buf then
			on_buf(self)
		end
	end

	local terminal = LvimShellModules.win(opts.win)

	vim.api.nvim_buf_call(terminal.buf, function()
		local term_opts = {
			cwd = opts.cwd,
			env = opts.env,
		}
		vim.fn.termopen(
			cmd or M.parse(opts.shell or vim.o.shell),
			vim.tbl_isempty(term_opts) and vim.empty_dict() or term_opts
		)
	end)

	if opts.interactive ~= false then
		vim.cmd.startinsert()
		vim.api.nvim_create_autocmd("TermClose", {
			once = true,
			buffer = terminal.buf,
			callback = function()
				if type(vim.v.event) == "table" and vim.v.event.status ~= 0 then
					vim.notify(
						"Terminal exited with code " .. vim.v.event.status .. ".\nCheck for any errors.",
						vim.log.levels.ERROR,
						{
							title = "LVIM Shell Modules",
						}
					)
					return
				end
				terminal:close()
				vim.cmd.checktime()
			end,
		})
		vim.api.nvim_create_autocmd("BufEnter", {
			buffer = terminal.buf,
			callback = function()
				vim.cmd.startinsert()
			end,
		})
		terminal:on("ExitPre", function()
			terminal:close()
		end)
	end
	vim.cmd("noh")
	return terminal
end

--- Get or create a terminal window.
--- The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
--- `opts.create` defaults to `true`.
---@param cmd? string | string[]
---@param opts? lvim-shell-modules.terminal.Opts| {create?: boolean}
---@return lvim-shell-modules.win? terminal, boolean? created
function M.get(cmd, opts)
	opts = opts or {}
	local id = vim.inspect({ cmd = cmd, cwd = opts.cwd, env = opts.env, count = vim.v.count1 })
	local created = false
	if not (terminals[id] and terminals[id]:buf_valid()) and (opts.create ~= false) then
		terminals[id] = M.open(cmd, opts)
		created = true
	end
	return terminals[id], created
end

--- Toggle a terminal window.
--- The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
---@param cmd? string | string[]
---@param opts? lvim-shell-modules.terminal.Opts
function M.toggle(cmd, opts)
	local terminal, created = M.get(cmd, opts)
	return created and terminal or assert(terminal):toggle()
end

--- Parses a shell command into a table of arguments.
--- - spaces inside quotes (only double quotes are supported) are preserved
--- - backslash
---@private
---@param cmd string|string[]
---@return string[]
function M.parse(cmd)
	if type(cmd) == "table" then
		return cmd
	end
	local args = {}
	local in_quotes, escape_next, current = false, false, ""
	local function add()
		if #current > 0 then
			table.insert(args, current)
			current = ""
		end
	end

	for i = 1, #cmd do
		local char = cmd:sub(i, i)
		if escape_next then
			current = current .. ((char == '"' or char == "\\") and "" or "\\") .. char
			escape_next = false
		elseif char == "\\" and in_quotes then
			escape_next = true
		elseif char == '"' then
			in_quotes = not in_quotes
		elseif char:find("[ \t]") and not in_quotes then
			add()
		else
			current = current .. char
		end
	end
	add()
	return args
end

function M.colorize()
	vim.wo.number = false
	vim.wo.relativenumber = false
	vim.wo.statuscolumn = ""
	vim.wo.signcolumn = "no"
	vim.opt.listchars = { space = " " }

	local buf = vim.api.nvim_get_current_buf()

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	while #lines > 0 and vim.trim(lines[#lines]) == "" do
		lines[#lines] = nil
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

	vim.api.nvim_chan_send(vim.api.nvim_open_term(buf, {}), table.concat(lines, "\r\n"))
	vim.keymap.set("n", "q", "<cmd>q<cr>", { silent = true, buffer = buf })
	vim.api.nvim_create_autocmd("TextChanged", {
		buffer = buf,
		callback = function()
			pcall(vim.api.nvim_win_set_cursor, 0, { #lines, 0 })
		end,
	})
	vim.api.nvim_create_autocmd("TermEnter", { buffer = buf, command = "stopinsert" })
end

return M
