-- this is just lua, so you can do whatever.
-- this, for example, is a global variable
local URL = "http://localhost:1323"

-- this here is an dynamic variable. a `store = {}` table saves them to a file nearby
local AUTH = "Authorization: Bearer {{TOKEN}}"
-- if you need normal env vars, we have os.getenv in lua

-- the request table needs to be returned as per types.d.lua
-- if you don't have a language server for lua, i highly recommend you install one
---@type request[]
return {
	{
		url = URL .. "/auth/refresh",
		method = "GET",
		headers = {
			AUTH,
		},
	},
	{
		url = URL .. "/auth/register",
		method = "POST",
		body = {
			-- refer to the first line. i run your functions every
			-- time you look at them for the clarity of your code, too
			-- user = "user_" .. math.random(0, 1000),
			user = os.getenv("XDG_CONFIG_HOME") or "",
			password = function()
				local charset = {}
				for _ = 1, 12 do
					table.insert(charset, string.char(math.random(48, 122)))
				end
				return table.concat(charset)
			end,
		},
		save = {
			token = "TOKEN",
		},
	},
	{
		url = URL .. "/auth/login",
		method = "POST",
		body = {
			name = "{{CUR_USER}}",
			password = "{{CUR_PASSWORD}}",
		},
	},
}
