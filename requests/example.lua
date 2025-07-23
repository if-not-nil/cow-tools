-- this is just lua, so you can do whatever.
-- this, for example, is a global variable
local URL = "https://api.chucknorris.io/jokes/random"

---@type request[]
return {
  {
    url = URL,
    method = "GET",
  },
}
