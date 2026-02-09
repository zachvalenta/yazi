--- @sync peek
local M = {}

-- Catppuccin Mocha color scheme
local COLORS = {
	header1 = "#f38ba8",      -- Red - Top level headers
	header2 = "#fab387",      -- Peach - Second level headers
	header3 = "#f9e2af",      -- Yellow - Third level headers
	header4 = "#a6e3a1",      -- Green - Fourth level headers
	class = "#f9e2af",        -- Yellow - Classes, structs, enums, types
	function_def = "#89b4fa", -- Blue - Functions, methods
	export = "#cba6f7",       -- Mauve - Exports, public items
}

-- Extract symbols with type information for coloring
local function extract_symbols(path, ext)
	local file = io.open(path, "r")
	if not file then
		return { { type = "error", text = "ERROR: Could not open file" } }
	end

	local symbols = {}

	for line in file:lines() do
		local symbol = nil
		local symbol_type = nil

		if ext == "md" then
			-- Markdown headers with level-based coloring
			local level, text = line:match("^(#+)%s+(.+)")
			if level then
				local indent = string.rep("  ", #level - 1)
				local color_key = "header" .. math.min(#level, 4)
				symbol = indent .. text
				symbol_type = color_key
			end

		elseif ext == "py" then
			-- Python classes and functions
			local class_name = line:match("^class%s+([%w_]+)")
			if class_name then
				symbol = "class " .. class_name
				symbol_type = "class"
			else
				local func_name = line:match("^%s*def%s+([%w_]+)")
				if func_name then
					local indent_str = line:match("^(%s*)")
					local indent = indent_str == "" and "" or "  "
					symbol = indent .. "def " .. func_name .. "()"
					symbol_type = "function_def"
				end
			end

		elseif ext == "lua" then
			-- Lua functions
			local func_name = line:match("^%s*function%s+[%w_.]*:?([%w_]+)")
			if func_name then
				symbol = "function " .. func_name .. "()"
				symbol_type = "function_def"
			else
				local local_func = line:match("^%s*local%s+function%s+([%w_]+)")
				if local_func then
					symbol = "local function " .. local_func .. "()"
					symbol_type = "function_def"
				end
			end

		elseif ext == "js" or ext == "ts" or ext == "jsx" or ext == "tsx" or ext == "mjs" then
			-- JavaScript/TypeScript
			local class_name = line:match("^%s*class%s+([%w_]+)")
			if class_name then
				symbol = "class " .. class_name
				symbol_type = "class"
			else
				local func_name = line:match("^%s*function%s+([%w_]+)")
				if func_name then
					symbol = "function " .. func_name .. "()"
					symbol_type = "function_def"
				else
					local const_func = line:match("^%s*const%s+([%w_]+)%s*=%s*%(")
					if const_func then
						symbol = "const " .. const_func .. " = ()"
						symbol_type = "function_def"
					else
						local export_func = line:match("^%s*export%s+function%s+([%w_]+)")
						if export_func then
							symbol = "export function " .. export_func .. "()"
							symbol_type = "export"
						end
					end
				end
			end

		elseif ext == "rs" then
			-- Rust
			local fn_name = line:match("^%s*pub%s+fn%s+([%w_]+)")
			if fn_name then
				symbol = "pub fn " .. fn_name .. "()"
				symbol_type = "export"
			else
				local priv_fn = line:match("^%s*fn%s+([%w_]+)")
				if priv_fn then
					symbol = "fn " .. priv_fn .. "()"
					symbol_type = "function_def"
				else
					local struct_name = line:match("^%s*pub%s+struct%s+([%w_]+)")
					if struct_name then
						symbol = "pub struct " .. struct_name
						symbol_type = "export"
					else
						local enum_name = line:match("^%s*pub%s+enum%s+([%w_]+)")
						if enum_name then
							symbol = "pub enum " .. enum_name
							symbol_type = "export"
						else
							local impl_name = line:match("^%s*impl%s+([%w_<>]+)")
							if impl_name then
								symbol = "impl " .. impl_name
								symbol_type = "class"
							end
						end
					end
				end
			end

		elseif ext == "go" then
			-- Go
			local func_name = line:match("^func%s+([%w_]+)")
			if func_name then
				symbol = "func " .. func_name .. "()"
				symbol_type = "function_def"
			else
				local method = line:match("^func%s+%([^)]+%)%s+([%w_]+)")
				if method then
					symbol = "func " .. method .. "()"
					symbol_type = "function_def"
				else
					local type_name = line:match("^type%s+([%w_]+)")
					if type_name then
						symbol = "type " .. type_name
						symbol_type = "class"
					end
				end
			end

		elseif ext == "rb" then
			-- Ruby
			local class_name = line:match("^%s*class%s+([%w_:]+)")
			if class_name then
				symbol = "class " .. class_name
				symbol_type = "class"
			else
				local method_name = line:match("^%s*def%s+([%w_?!]+)")
				if method_name then
					symbol = "def " .. method_name
					symbol_type = "function_def"
				end
			end

		elseif ext == "sh" or ext == "bash" or ext == "zsh" then
			-- Shell functions
			local func_name = line:match("^([%w_]+)%(%)")
			if func_name then
				symbol = "function " .. func_name .. "()"
				symbol_type = "function_def"
			else
				local func_keyword = line:match("^function%s+([%w_]+)")
				if func_keyword then
					symbol = "function " .. func_keyword .. "()"
					symbol_type = "function_def"
				end
			end
		end

		if symbol then
			table.insert(symbols, { type = symbol_type, text = symbol })
		end
	end

	file:close()

	if #symbols == 0 then
		return { { type = "info", text = "No symbols found" } }
	end
	return symbols
end

function M:peek(job)
	local url_str = tostring(job.file.url)
	local ext = url_str:match("%.([^./]+)$")

	if not ext then
		return require("empty"):peek(job)
	end

	-- Extract the file path (remove file:// prefix if present)
	local path = url_str:gsub("^file://", "")

	local symbols = extract_symbols(path, ext)

	-- Create colored text lines
	local lines = {}
	for _, sym in ipairs(symbols) do
		local color = COLORS[sym.type] or "white"
		local span = ui.Span(sym.text):style(ui.Style():fg(color))
		table.insert(lines, ui.Line { span })
	end

	ya.preview_widget(job, { ui.Text(lines):area(job.area) })
end

function M:seek() end

return M
