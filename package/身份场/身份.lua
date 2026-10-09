-- 身份：给一名角色定下身份（身份场专用；真相写在玩家的 custom 里，主公正面朝上）

---@class Player
local M = Class 'Player'

---@type 身份场.身份?
M.identity = nil

---@param self Player
---@return 身份场.身份? # 身份（只读：真相在 custom 里）
M.__getter.identity = function (self)
    return self.custom.proxy.identity
end

--- 给这名角色定下身份（定了之后要重算技能 —— 主公技只给主公）
---@param name 身份场.身份
function M:setIdentity(name)
    self.custom.proxy.identity = name
    self.custom:setVisible('identity', name == '主公')
    self:refreshSkills()
end

--- 这名角色的身份牌对某人可见吗（主公正面朝上；自己的看得见自己的；其余背面朝上）
---@param viewer Player
---@return boolean
function M:isIdentityVisibleTo(viewer)
    return self.custom:isVisible('identity', viewer)
end
