local M = {
	_config = require("buffers.config"),
	_hl_groups = {},
	_count = 0,
	_ns_id = vim.api.nvim_create_namespace("buffers"),
}

-- % setup %
function M.setup(new_config)
	M._config:set(new_config)
end

-- % open %
function M.open()
	if M._is_open() then
		return
	end

	local prev_winnr = vim.api.nvim_get_current_win()
	local prev_bufnr = vim.api.nvim_get_current_buf()

	local buffers = M._get_buffers()

	local bufnr, winnr = M._create_window(buffers)

	local get_buffers = function()
		return buffers
	end

	local set_buffers = function(new_buffers)
		buffers = new_buffers
	end

	M._bind_keymap(bufnr, winnr, prev_winnr, prev_bufnr, get_buffers, set_buffers)

	M._write_buffers(bufnr, buffers, prev_bufnr)

	M._focus_on_current_buffer(prev_bufnr, buffers, winnr)
end

-- % get_buffers %
function M._get_buffers()
	local bufnr_list = vim.api.nvim_list_bufs()
	local dir = vim.fn.getcwd()

	return vim.iter(bufnr_list)
		:filter(function(bufnr)
			return M._config:get().enable(bufnr)
		end)
		:map(function(bufnr)
			local modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })

			local diagnostics = M._get_buffer_diagnostics(bufnr)

			local path = vim.api.nvim_buf_get_name(bufnr)
			local index = path:find(dir, nil, true)
			local relative_path = index and path:sub(index + #dir + 1) or path

			local type = vim.filetype.match({ filename = path })

			return {
				bufnr = bufnr,
				modified = modified,
				path = relative_path,
				type = type,
				diagnostics = diagnostics,
			}
		end)
		:totable()
end

-- % get_buffer_diagnostics %
function M._get_buffer_diagnostics(bufnr)
	local diagnostics = vim.diagnostic.get(bufnr, {})

	local error = 0
	local warn = 0
	local info = 0
	local hint = 0

	for _, diagnostic in ipairs(diagnostics) do
		if diagnostic.severity == vim.diagnostic.severity.ERROR then
			error = error + 1
		elseif diagnostic.severity == vim.diagnostic.severity.WARN then
			warn = warn + 1
		elseif diagnostic.severity == vim.diagnostic.severity.INFO then
			info = info + 1
		elseif diagnostic.severity == vim.diagnostic.severity.HINT then
			hint = hint + 1
		end
	end

	return {
		error = error,
		warn = warn,
		info = info,
		hint = hint,
	}
end

-- % create_window %
function M._create_window(buffers)
	local bufnr = vim.api.nvim_create_buf(false, true)
	local winnr = vim.api.nvim_open_win(bufnr, true, M._get_window_options(M._config:get().window.width, #buffers))
	vim.api.nvim_set_option_value("filetype", "buffers", { buf = bufnr })

	return bufnr, winnr
end

-- % get_window_options %
function M._get_window_options(width, height)
	local screen_w = vim.opt.columns:get()
	local window_w = width
	local window_h = height
	local window_w_int = math.floor(window_w)
	local window_h_int = math.floor(window_h)
	local center_x = (screen_w - window_w) / 2
	local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()

	return {
		relative = "editor",
		width = window_w_int,
		height = window_h_int,
		row = center_y,
		col = center_x,
		border = "rounded",
		title = "buffer list",
		style = "minimal",
		title_pos = "center",
	}
end

-- % write_buffers %
function M._write_buffers(bufnr, buffers, prev_bufnr)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

	local function get_line(buffer, index)
		local icon, color = require("nvim-web-devicons").get_icon_color_by_filetype(buffer.type)

		local parts = {
			buffer.modified and "⬤" or " ",
			" ",
			icon,
			" ",
			buffer.path,
			" ",
			buffer.diagnostics.error > 0 and buffer.diagnostics.error .. "" or "",
			buffer.diagnostics.warn > 0 and buffer.diagnostics.warn .. "" or "",
			buffer.diagnostics.info > 0 and buffer.diagnostics.info .. "" or "",
			buffer.diagnostics.hint > 0 and buffer.diagnostics.hint .. "" or "",
		}
		local text = vim.fn.join(parts, "")

		local colors = {
			"#FFFF00",
			"#FFFFFF",
			color,
			"#FFFFFF",
			buffer.bufnr == prev_bufnr and "#00FF7F" or "#808080",
			"#FFFFFF",
			"#FF0000",
			"#FF8C00",
			"#87CEFA",
			"#7FFFD4",
		}

		local highight = {}

		local function get_prev_len(i)
			local len = 0
			vim.iter(parts):slice(1, i):each(function(part)
				len = len + string.len(part)
			end)
			return len
		end

		for i, x in ipairs(colors) do
			highight[x] = {
				start = { index - 1, get_prev_len(i - 1) },
				finish = { index - 1, get_prev_len(i) },
			}
		end

		return text, highight
	end

	local highlights = {}
	local lines = vim.iter(ipairs(buffers))
		:map(function(index, buffer)
			local text, highlight = get_line(buffer, index)
			table.insert(highlights, highlight)
			return text
		end)
		:totable()

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

	M._highlight_buffers(highlights, bufnr)
end

-- % highlight_buffers %
function M._highlight_buffers(highlights, bufnr)
	for _, highlight in ipairs(highlights) do
		for color, range in pairs(highlight) do
			if range.start[1] == range.finish[1] and range.start[2] == range.finish[2] then
				goto continue
			end

			local hl = M._hl_groups[color]

			if not hl then
				hl = "Buffers" .. M._count
				M._count = M._count + 1
				vim.api.nvim_set_hl(0, hl, { fg = color })
				M._hl_groups[color] = hl
			end

			vim.hl.range(bufnr, M._ns_id, hl, range.start, range.finish)

			::continue::
		end
	end
end

-- % bind_keymap %
function M._bind_keymap(bufnr, winnr, prev_winnr, prev_bufnr, get_buffers, set_buffers)
	vim.api.nvim_buf_set_keymap(bufnr, "n", M._config:get().keymap.quit, "", {
		callback = function()
			M._close(bufnr, winnr)
		end,
	})

	vim.api.nvim_buf_set_keymap(bufnr, "n", M._config:get().keymap.enter, "", {
		callback = function()
			local buffer = M._get_selected_buffer(get_buffers())
			if not buffer then
				return
			end

			M._close(bufnr, winnr)
			vim.api.nvim_set_current_win(prev_winnr)
			vim.api.nvim_win_set_buf(prev_winnr, buffer.bufnr)
		end,
	})

	vim.api.nvim_buf_set_keymap(bufnr, "n", M._config:get().keymap.close_buffer, "", {
		callback = function()
			local buffer = M._get_selected_buffer(get_buffers())

			vim.api.nvim_buf_delete(buffer.bufnr, {})

			vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
			local cursor = vim.api.nvim_win_get_cursor(0)
			vim.api.nvim_buf_set_lines(bufnr, cursor[1] - 1, cursor[1], false, {})
			vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

			set_buffers(vim.iter(get_buffers())
				:filter(function(b)
					return b.bufnr ~= buffer.bufnr
				end)
				:totable())

			if prev_bufnr == buffer.bufnr then
				local fallback_buffer = get_buffers()[1]
				if not fallback_buffer then
					M._close(bufnr, winnr)
				end
				vim.api.nvim_win_set_buf(
					prev_winnr,
					fallback_buffer and fallback_buffer.bufnr or vim.api.nvim_create_buf(false, true)
				)
			end
		end,
	})
end

-- % get_selected_buffer %
function M._get_selected_buffer(buffers)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local buffer = buffers[cursor[1]]
	return buffer
end

-- % close %
function M._close(bufnr, winnr)
	pcall(function()
		vim.api.nvim_win_close(winnr, true)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end

-- % focus_on_current_buffer %
function M._focus_on_current_buffer(prev_bufnr, buffers, winnr)
	for lnum, buffer in ipairs(buffers) do
		if buffer.bufnr == prev_bufnr then
			vim.api.nvim_win_set_cursor(winnr, { lnum, 0 })
		end
	end
end

-- % is_open %
function M._is_open()
	return vim.iter(vim.api.nvim_list_bufs()):find(function(bufnr)
		return vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == "buffers"
	end)
end

return M
