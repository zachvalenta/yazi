--- @sync peek
local M = {}

-- Extract symbols based on file extension
local function extract_symbols(path, ext)
	local file = io.open(path, "r")
	if not file then
		return { "ERROR: Could not open file" }
	end

	local symbols = {}
	local line_num = 0

	for line in file:lines() do
		line_num = line_num + 1
		local symbol = nil

		if ext == "md" then
			-- Markdown headers
			local level, text = line:match("^(#+)%s+(.+)")
			if level then
				local indent = string.rep("  ", #level - 1)
				symbol = string.format("%s%s", indent, text)
			end

		elseif ext == "py" then
			-- Python classes and functions
			local class_name = line:match("^class%s+([%w_]+)")
			if class_name then
				symbol = string.format("class %s", class_name)
			else
				local func_name = line:match("^%s*def%s+([%w_]+)")
				if func_name then
					local indent = line:match("^(%s*)")
					if indent == "" then
						symbol = string.format("def %s()", func_name)
					else
						symbol = string.format("  def %s()", func_name)
					end
				end
			end

		elseif ext == "lua" then
			-- Lua functions
			local func_name = line:match("^%s*function%s+[%w_.]*:?([%w_]+)")
			if func_name then
				symbol = string.format("function %s()", func_name)
			else
				local local_func = line:match("^%s*local%s+function%s+([%w_]+)")
				if local_func then
					symbol = string.format("local function %s()", local_func)
				end
			end

		elseif ext == "js" or ext == "ts" or ext == "jsx" or ext == "tsx" or ext == "mjs" then
			-- JavaScript/TypeScript classes, functions, exports
			local class_name = line:match("^%s*class%s+([%w_]+)")
			if class_name then
				symbol = string.format("class %s", class_name)
			else
				local func_name = line:match("^%s*function%s+([%w_]+)")
				if func_name then
					symbol = string.format("function %s()", func_name)
				else
					local const_func = line:match("^%s*const%s+([%w_]+)%s*=%s*%(")
					if const_func then
						symbol = string.format("const %s = ()", const_func)
					else
						local export_func = line:match("^%s*export%s+function%s+([%w_]+)")
						if export_func then
							symbol = string.format("export function %s()", export_func)
						end
					end
				end
			end

		elseif ext == "rs" then
			-- Rust functions, structs, enums, impls
			local fn_name = line:match("^%s*pub%s+fn%s+([%w_]+)")
			if fn_name then
				symbol = string.format("pub fn %s()", fn_name)
			else
				local priv_fn = line:match("^%s*fn%s+([%w_]+)")
				if priv_fn then
					symbol = string.format("fn %s()", priv_fn)
				else
					local struct_name = line:match("^%s*pub%s+struct%s+([%w_]+)")
					if struct_name then
						symbol = string.format("pub struct %s", struct_name)
					else
						local enum_name = line:match("^%s*pub%s+enum%s+([%w_]+)")
						if enum_name then
							symbol = string.format("pub enum %s", enum_name)
						else
							local impl_name = line:match("^%s*impl%s+([%w_<>]+)")
							if impl_name then
								symbol = string.format("impl %s", impl_name)
							end
						end
					end
				end
			end

		elseif ext == "go" then
			-- Go functions, types, structs
			local func_name = line:match("^func%s+([%w_]+)")
			if func_name then
				symbol = string.format("func %s()", func_name)
			else
				local method = line:match("^func%s+%([^)]+%)%s+([%w_]+)")
				if method then
					symbol = string.format("func %s()", method)
				else
					local type_name = line:match("^type%s+([%w_]+)")
					if type_name then
						symbol = string.format("type %s", type_name)
					end
				end
			end

		elseif ext == "rb" then
			-- Ruby classes and methods
			local class_name = line:match("^%s*class%s+([%w_:]+)")
			if class_name then
				symbol = string.format("class %s", class_name)
			else
				local method_name = line:match("^%s*def%s+([%w_?!]+)")
				if method_name then
					symbol = string.format("def %s", method_name)
				end
			end

		elseif ext == "sh" or ext == "bash" or ext == "zsh" then
			-- Shell functions
			local func_name = line:match("^([%w_]+)%(%)")
			if func_name then
				symbol = string.format("function %s()", func_name)
			else
				local func_keyword = line:match("^function%s+([%w_]+)")
				if func_keyword then
					symbol = string.format("function %s()", func_keyword)
				end
			end
		end

		if symbol then
			table.insert(symbols, string.format("%4d: %s", line_num, symbol))
		end
	end

	file:close()

	if #symbols == 0 then
		return { "No symbols found" }
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

	-- Create text widget
	local lines = {}
	for _, symbol in ipairs(symbols) do
		table.insert(lines, ui.Line(symbol))
	end

	ya.preview_widget(job, { ui.Text(lines):area(job.area) })
end

function M:seek() end

return M
