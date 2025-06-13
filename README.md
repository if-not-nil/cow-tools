# cow tools
> [no, the moon](https://if-not-nil.github.io/no-the-moon/)

a lightweight lua-based api testing framework  
<img width="710" alt="to save" src="https://github.com/user-attachments/assets/9ae13dfa-0a8f-48fb-bde0-10ccb2873db9" />

## features
- any valid lua code can be used
- use fzf to go through requests
- small and easy to modify if something doesn't work
- it's easy to fully understand
- your text editor if your GUI

## installation
you need both curl and lua installed  
an LSP is recommended to get type hints when writing requests  
```bash
git clone https://github.com/if-not-nil/cow-tools
cd cow-tools
echo alias cows='"'lua $(pwd)/main.lua'"' >> ~/.bashrc
```

or run directly
`lua $PWD/main.lua`


## usage
make a lua file  
this is the simplest way to use it. save it to first.lua in your working directory  
```lua
# first.lua
---@type request[]
return {
	{
		url = "https://jsonplaceholder.typicode.com/todos/1",
		method = "GET",
	},
}
```
this does just what you think it does
now, run `cows first.lua 1`  
<img width="734" alt="placeholder" src="https://github.com/user-attachments/assets/5bf85b8c-974c-41cf-b540-c77828059170" />  

now, if you have fzf, try running `cows first`  
it's not colorized or anything yet, but it helps you keep up with the requests you have

here's a better example
```lua
# first.lua
-- this is just lua, so you can do whatever.
-- this, for example, is a global variable
local URL = "http://localhost:1323"

-- this here is an dynamic variable. a `store = {}` table saves them to a file nearby
local AUTH = "Authorization: Bearer {{TOKEN}}"
-- for normat env vars, use os.getenv

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
      -- saves to a file next to this one, if your file is requests.lua, it'll be saved to requests_var.lua
			token = "TOKEN",
		},
	},
	{
		url = URL .. "/auth/login",
		method = "POST",
		body = {
      -- gets CUR_USER from [filename]_var.lua
			name = "{{CUR_USER}}",
			password = "{{CUR_PASSWORD}}",
		},
	},
}

```  

## contributing
this codebase is yours just as much as it is mine  
if you feel like you've added something everybody will appreciate, please make a pull request

### what's next
[ ] request names, when calling with no fzf should both be able to be like [METHOD]:[path] (path being the shortest possible without colliding from the top)  
[ ] multipart support. maybe a cosmopolitan libc .so library that can generate random files to test the api?  
[ ] structure the code in a way obvious to the reader  
[ ] named requests  
[ ] chaining requests (maybe a table called chains which sequentially executes either named requests or normal ones?)
[ ] init argument which will copy the type definitions and create a blank requests file for you  
[ ] pretty print json  

### why is it called cow tools
because of cow tools the comic  
lua -> moon -> moo, and mootools is takes

### licenses:
* [rxi/json](https://github.com/rxi/json) MIT  
