
---@alias method "POST" | "GET" | "PUT" | "DELETE"

---@class request
---@field method method
---@field url string
---@field body? table
---@field headers? table<string, string> | string[]
---@field save? tuple[]

---@class tuple
---@field T any
---@field T2 any
