-- 距离（官方通用口径）：座位距离 + 双方的修正，结算后最小 1
-- 进攻修正读自己的（进攻马 -1）、防御修正读对方的（防御马 +1）；修正值由装备写进属性（@基础/装备.lua）
local attributeSystem = game:getAttributeSystem()

attributeSystem:define('进攻修正', { simple = true })
attributeSystem:define('防御修正', { simple = true })

-- 距离（谁到谁）
---@param from Player
---@param to Player
---@return integer
---@diagnostic disable-next-line: lowercase-global
function distance(from, to)
    local value = game.desk:getDistance(from, to)
                + from:getAttr('进攻修正')
                + to:getAttr('防御修正')
    if value < 1 then
        return 1
    end
    return value
end
