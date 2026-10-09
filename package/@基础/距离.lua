-- 距离（官方通用口径）：座位距离 + 双方的修正，结算后最小 1
-- 进攻修正读自己的（进攻马 -1）、防御修正读对方的（防御马 +1）；修正值由装备写进属性（@基础/装备.lua）
-- distance 只给真值；射程判断走 isInRange（认使用选项的「无视距离」）
local attributeSystem = game:getAttributeSystem()

attributeSystem:define('进攻修正', { simple = true })
attributeSystem:define('防御修正', { simple = true })

--- 这次使用的选项（内核只管它自己读的几条；`ignoreDistance` 是距离这边认的，就近声明）
---@class Game.UseOptions
---@field ignoreDistance? boolean # 无视距离（`isInRange` 认它：这次使用的射程判断直接算在）

---@class Game.UseOptionsInput
---@field ignoreDistance? boolean

---@class Player
local M = Class 'Player'

--- 距离（谁到谁）
---@param to Player
---@return integer
function M:distance(to)
    local value = self.game.desk:getDistance(self, to)
                + self:getAttr('进攻修正')
                + to:getAttr('防御修正')
    if value < 1 then
        return 1
    end
    return value
end

--- 在不在射程内（选项说「无视距离」就直接算在）
---@param to Player
---@param range integer
---@param useOptions? Game.UseOptions # 这次使用的选项（认 `ignoreDistance`）
---@return boolean
function M:isInRange(to, range, useOptions)
    if useOptions?.ignoreDistance then
        return true
    end
    return self:distance(to) <= range
end
