local lume = require("lib.lume")
local json = require("lib.json")
local util = require("util") -- i am not exactly sure whether lua has a "pragma once" kinda thing by default
local log = util.log
local panic = util.panic
local panicif = util.panicif

local function exec(cmd)
	local tmpfile = os.tmpname()
	local fullcmd = string.format("%s 2> %s", cmd, tmpfile)
	local pipe = io.popen(fullcmd, "r")

	panicif("can't run curl. are you sure it's in your path?", pipe == nil)

	-- dawg im already checking nil
	---@diagnostic disable-next-line: need-check-nil
	local stdout = pipe:read("*a")
	---@diagnostic disable-next-line: need-check-nil
	pipe:close()

	local f = io.open(tmpfile, "r")
	local stderr = ""
	if f then
		stderr = f:read("*a")
		f:close()
		os.remove(tmpfile)
	end

	return stdout, stderr
end

---@class program
---@field reqt request[]
---@field store table<string, string>
---@field self_path string
local A = { reqt = {}, store = {} }

---@param value any
---@return any
function A:res(value)
	if type(value) == "function" then
		return self:res(value()) -- recursively resolve return
	elseif type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[self:res(k)] = self:res(v)
		end
		return out
	elseif type(value) == "string" then
		local resolved = value:gsub("{{(.+)}}", function(var)
			return tostring(self.store[var] or os.getenv(var) or "{{" .. var .. "}}")
		end)
		return resolved
	else
		return value
	end
end

---@param req request
---@return string curl_command
function A:to_curl(req)
	local cmd = { "curl", "-X", self:res(req.method), string.format("'%s'", self:res(req.url)) }

	-- headers
	if req.headers then
		for k, v in pairs(req.headers) do
			local key = self:res(k)
			local val = self:res(v)
			local header = type(key) == "number" and val or (key .. ": " .. val)
			table.insert(cmd, "-H " .. string.format("'%s'", header))
		end
	end

	-- body
	if req.body and req.body ~= nil then
		local resolved_body = {}
		for k, v in pairs(req.body) do
			resolved_body[self:res(k)] = self:res(v)
		end
		local encoded = json.encode(resolved_body)
		table.insert(cmd, "-d '" .. encoded .. "'")
	end

	return table.concat(cmd, " ")
end

---@param t table
---@param path string
local function save_table(t, path)
	local f = assert(io.open(path, "w+"))
	f:write("---@type table<string, string>\nreturn {\n")
	for k, v in pairs(t) do
		f:write(string.format("  [%q] = %q,\n", tostring(k), tostring(v)))
	end
	f:write("}\n")
	f:close()
end

function A:list_requests()
	local list = {}
	for i, t in pairs(self.reqt) do
		assert(t.method ~= nil and t.url ~= nil, "request " .. i .. ": both method and url fields are required")
		table.insert(list, (i .. ": " .. t.method .. " " .. t.url))
	end
	return table.concat(list, "\n")
end

function A:parse_fzf_res(out, i)
	local n = i or tonumber(string.match(out, "%d+"))
	local curl_cmd = self:to_curl(self.reqt[n]) .. " -w '%{http_code}'"
	local ret, err = exec(curl_cmd)
	panicif("error? " .. err, err)

	local status_code = tonumber(ret:sub(-3))
	local body = ret:sub(1, -4)

	log("\27[32mresponse:\27[0m")
	log(body)
	log("\n\27[32mstatus:\27[0m")
	log(status_code)

	if status_code ~= 200 then
		panic(string.format("\n\27[31mrequest failed!\27[0m %d", status_code))
	end

	local ok, jj = pcall(json.decode, body)
	if not ok then
		panic("failed to parse JSON: " .. tostring(jj))
	end

	if self.reqt[n].save ~= nil then
		local tpls = self.reqt[n].save

		local vals = (lume.map(tpls, function(k)
			return { k[2], jj[k[1]] }
		end))

		for _, pair in ipairs(vals) do
			local key, val = pair[1], pair[2]
			self.store[key] = val
			log(string.format("saved: %s = %s", key, val))
		end

		save_table(self.store, self.self_path .. "_var.lua")
	end
	log("\27[32mresponse:\27[0m")
	log(ret:sub(0, #ret - 4)) -- magic number. 3 chars for the return code and one for newline
	log("\n\27[32mstatus:\27[0m")
	log(ret:sub(-3))
end

function A:parse_store()
	panicif("no reqt value set", self.reqt == nil)
	local store_file = self.self_path .. "_var.lua"
	local _, err = io.open(store_file)
	if err ~= nil then
		self.store = {}
		save_table(self.store, store_file)
		return
	end
	self.store = require(self.self_path .. "_var")
end

---@param path string
function A:run(path)
	self.self_path = path
	self.reqt = require(self.self_path)
	self:parse_store()

	if tonumber(arg[2]) then
		self:parse_fzf_res(nil, tonumber(arg[2]))
		return
	end

	local t = self:list_requests()
	local self_cmd = table.concat(arg, " "):gsub(path, "") -- fallback
	local cmd, err = exec("echo '" .. t .. "' | fzf --preview '" .. self_cmd .. path .. " preview {} | cat '")
	panicif(err, err ~= nil)
	self:parse_fzf_res(cmd)
end

function A:preview(path)
	self.self_path = path
	local reqt = require(path)
	self:parse_store()
	local n = tonumber(string.match(arg[3], "%d+"))

	local resolved = self:res(reqt[n])
	log(resolved)
	os.exit(0)
end

local program = A

--
-- this is the part where the executable is ran
--

if #arg < 1 then
	local ret = "\27[31minvalid params! \27[0musage:\n"
	for _, a in pairs(arg) do
		ret = ret .. a .. " "
	end
	ret = ret .. "[requests.lua] [optional: number | preview]"
	panic(ret)
	os.exit(-1)
end

local path = ""
if string.match(arg[1], "%S+lua") then
	path = string.sub(arg[1], 1, #arg[1] - 4)
else
	path = arg[1]
end

if arg[2] == "preview" then
	program:preview(path)
end

panicif("no file provided", path ~= nil, path == "")

program:run(path)

os.exit(0)
