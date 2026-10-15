-- 身份：给一名角色定下身份（身份场专用；真相写在玩家的 custom 里，主公正面朝上）

---@class Player
local M = Class 'Player'

--- 给这名角色定下身份（定了之后要重算技能 —— 主公技只给主公）
---@param name 身份场.身份
function M:setIdentity(name)
    self.custom.identity = name
    -- 主公正面朝上（人人看得见）；其余背面朝上 —— 新口径下「本人」也得显式声明才看得见
    self:setCustomVisible('identity', name == '主公' and true or self)
    self:refreshSkills()
end

--- 这名角色的身份牌对某人可见吗（主公正面朝上；自己的看得见自己的；其余背面朝上）
---@param viewer Player
---@return boolean
function M:isIdentityVisibleTo(viewer)
    return self:isCustomVisibleTo('identity', viewer)
end

--- 把身份牌翻给所有人看（结算画面用）
function M:revealIdentity()
    self:setCustomVisible('identity', true)
end

-- 结局：所有人的身份牌都翻开来（胜负定了就没必要再藏着）
game:on('游戏-结束', function ()
    for _, player in ipairs(game.desk.players) do
        player:revealIdentity()
    end
end)
