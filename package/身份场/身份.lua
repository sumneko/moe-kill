-- 身份：给一名角色定下身份（身份场专用；读直接用字段 player.identity）

---@class Player
local M = Class 'Player'

--- 给这名角色定下身份（定了之后要重算技能 —— 主公技只给主公）
---@param name 身份场.身份
function M:setIdentity(name)
    self.identity = name
    self:refreshSkills()
end

--- 这名角色的身份牌对某人可见吗（主公正面朝上；自己的看得见自己的；其余背面朝上）
---@param viewer Player
---@return boolean
function M:isIdentityVisibleTo(viewer)
    return self.identity == '主公' or self == viewer
end
