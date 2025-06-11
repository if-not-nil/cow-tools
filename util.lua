local util = {}

---@param tbl table
---@param indent? number
---there was no good reason for me to implement it other than learning, since inspect.lua is just there
---if another person is reading this and wants themselves a little excercise to complete, you can make this function better!
---maybe another function to print it with color? or something that smartly rips out all newline chars?
function util.unfold_table(tbl, indent)
	if type(tbl) ~= "table" then
		return tostring(tbl)
	end
	-- TODO: if no indent, inline everything
	indent = indent or 0
	local ret = "{\n"
	local prefix = string.rep("  ", indent + 1)
	for k, v in pairs(tbl) do
		local keyStr = k
		if type(k) == "number" then
			keyStr = k .. ":"
		else
			keyStr = k .. " = "
		end
		if type(v) == "table" then
			ret = ret .. prefix .. keyStr .. util.unfold_table(v, indent + 1) .. "\n"
		else
			ret = ret .. prefix .. keyStr .. tostring(v) .. "\n"
		end
	end
	ret = ret .. string.rep("  ", indent) .. "}"
	return ret
end

---since tables encompass everything unstringifiable, this is like {:any} in rust or %v in go
function util.log(...)
	local w = io.stdout
	-- w:write("[log] ")
	for _, v in ipairs({ ... }) do
		if type(v) == "table" then
			w:write(util.unfold_table(v) .. "\n")
		else
			w:write(tostring(v) .. "\n")
		end
	end
	w:flush()
end

---explain to those who think like machines
util.panic = function(err)
	io.stderr:write(err .. "\n")
	io.stderr:close()
	os.exit(-1)
end

---@arg string message
---@arg ... boolean conditions
-- to remember:
-- panic if "file not found" *hey machine, this is what file not found means in your language*
util.panicif = function(message, ...)
	local conditions = { ... }
	for c in pairs(conditions) do
		if not c then
			io.stderr:write(message .. "\n")
			io.stderr:close()
			os.exit(-1)
		end
	end
end

return util
