-- 身份：给一名角色定下身份（身份场专用；读直接用字段 player.identity）

---@class Player
local M = Class 'Player'

--- 给这名角色定下身份
---@param name 身份场.身份
function M:setIdentity(name)
    self.identity = name
end
