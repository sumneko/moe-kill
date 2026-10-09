require 'user.user'

--- 真实玩家的代表：把询问下发给客户端、等客户端回话（协议还没做，先把接口留在这儿）
---@class ClientUser : User
local M = Class 'ClientUser'

Extends('ClientUser', 'User')

return M
