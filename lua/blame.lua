local M = {}
local ns = vim.api.nvim_create_namespace("blame")
local enabled, timer = false, nil

local function in_git()
	local ok = vim.system({ "git", "rev-parse", "--is-inside-work-tree" },
		{ cwd = vim.fn.expand("%:p:h") }):wait()
	return ok.code == 0
end

local function reltime(sec)
	local d = os.time() - sec
	if d < 90 then return d .. "s" end
	if d < 5400 then return math.floor(d / 60) .. "m" end
	if d < 129600 then return math.floor(d / 3600) .. "h" end
	if d < 4838400 then return math.floor(d / 86400) .. "d" end
	if d < 63072000 then return math.floor(d / 2629800) .. "mo" end
	return math.floor(d / 31557600) .. "y"
end

local function clear() vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) end

local function show()
	if not enabled or not in_git() then return end
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or vim.fn.getfsize(path) > 800 * 1024 then return end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local res = vim.system(
		{ "git", "blame", "--line-porcelain", "-L", lnum .. "," .. lnum, path },
		{ cwd = vim.fn.expand("%:p:h") }
	):wait()
	if res.code ~= 0 then return end
	local author, atime, summary = "?", nil, ""
	for line in res.stdout:gmatch("[^\r\n]+") do
		if line:find("^author ") then
			author = line:sub(8)
		elseif line:find("^author%-time ") then
			atime = tonumber(line:sub(13))
		elseif line:find("^summary ") then
			summary = line:sub(9)
		end
	end
	if not atime then return end
	local msg = string.format("  %s • %s • %s", author, reltime(atime), summary)
	clear()
	vim.api.nvim_buf_set_extmark(0, ns, lnum - 1, 0, {
		virt_text = { { msg, "BlameVirtText" } },
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

function M.toggle()
	enabled = not enabled
	if enabled then show() else clear() end
end

function M.setup()
	vim.api.nvim_set_hl(0, "BlameVirtText", { link = "Comment" })
	vim.api.nvim_create_autocmd({ "CursorHold", "BufEnter", "TextChanged", "InsertLeave" }, {
		callback = function()
			if timer then
				timer:stop(); timer:close(); timer = nil
			end
			timer = vim.loop.new_timer()
			timer:start(100, 0, vim.schedule_wrap(show))
		end
	})
	vim.api.nvim_create_user_command("BlameToggle", M.toggle, {})
end

return M
