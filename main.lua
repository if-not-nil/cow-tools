local function get_script_dir()
	local info = debug.getinfo(1, "S")
	local script_path = info.source:sub(2)
	return script_path:match("(.*/)")
end

local script_dir = get_script_dir() or "./"

package.path = script_dir .. "?.lua;" .. script_dir .. "lib/?.lua;" .. package.path
package.cpath = script_dir .. "lib/?.so;" .. package.cpath

local json = require("lib.json")
local util = require("lib.util") -- i am not exactly sure whether lua has a "pragma once" kinda thing by default
local log = util.log
local panic = util.panic
local panicif = util.panicif

local function exec(cmd)
	local tmpfile = os.tmpname()
	local fullcmd = string.format("%s 2> %s", cmd, tmpfile)
	local pipe = io.popen(fullcmd, "r")

	panicif("can't run command. are you sure it's in your path?", pipe == nil)

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
---@field store table
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
	if req.body then
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
	f:write("---@type table\nreturn {\n")
	for k, v in pairs(t) do
		f:write(string.format("  [%q] = %q,\n", tostring(k), tostring(v)))
	end
	f:write("}\n")
	f:close()
end

function A:list_requests()
	local list = {}
	for i, t in ipairs(self.reqt) do
		panicif("request " .. i .. " is missing method or url", not (t.method and t.url))
		table.insert(list, (i .. ": " .. t.method .. " " .. t.url))
	end
	return table.concat(list, "\n")
end

function A:parse_fzf_res(out, n)
	if not n then
		n = tonumber(string.match(out, "%d+"))
	end
	local curl_cmd = self:to_curl(self.reqt[n]) .. " -w '%{http_code}'"
	local ret, err = exec(curl_cmd)
	panicif("error? " .. err, err)

	local status_code = tonumber(ret:sub(-3))
	local body = ret:sub(1, -4)

	if #body > 0 then
		log("\27[32m=====> response\27[0m")
		log(body)
	end

	if status_code ~= 200 then
		log("\27[31m=====> request failed \27[0m")
		log("\27[31m       status: \27[0m")
		panic(status_code)
	else
		log("\27[32m=====> status:\27[0m")
		log(status_code)
	end

	local ok, jj = pcall(json.decode, body)
	if not ok then
		return
	end
	-- this seems weird but i returned early because what comes next is only applicable when you got json

	local saved = {}
	local tpls = self.reqt[n].save
	if tpls ~= nil then
		local vals = {}
		for response_key, store_key in pairs(tpls) do
			vals[#vals + 1] = { store_key, jj[response_key] }
		end

		for _, pair in ipairs(vals) do
			local key, val = pair[1], pair[2]
			self.store[key] = val
			table.insert(saved, { key, val })
		end

		if #saved > 0 then
			log("\27[32m=====> saved:\27[0m")
			for _, v in pairs(saved) do
				log(string.format("* \27[33m     {{%s}}\27[0m", v[1]))
			end
			save_table(self.store, self.self_path .. "_var.lua")
		end
	end
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
	elseif arg[2] == "dryrun" then
		for i, req in ipairs(self.reqt) do
			log(i, self:to_curl(req), "\n")
		end
		os.exit(0)
	end

	local t = self:list_requests()
	local self_cmd = ""
	for i, a in pairs(arg) do
		if i < 1 then
			self_cmd = self_cmd .. a .. " "
		end
	end
	-- TODO: replace with any colored output. maybe bat?
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
	local ret = "usage:\n\27[33minteractive: \27[0m"
	for _, a in pairs(arg) do
		ret = ret .. a .. " "
	end
	ret = ret .. "[requests.lua]\n\27[33mrun by name: \27[0m"
	for _, a in pairs(arg) do
		ret = ret .. a .. " "
	end
	ret = ret .. "[requests.lua] [n]\n"
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
