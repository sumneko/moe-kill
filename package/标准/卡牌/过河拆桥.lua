-- 【过河拆桥】（标准版）
-- 出牌阶段，对一名区域里有牌的其他角色使用。你弃置其区域里的一张牌。
-- 服务器侧看得见所有牌（隐瞒是协议层的事）⇒ 目标的每个区都逐张当候选，挑中哪张就弃哪张。

---@param player Player
---@return boolean # 身上（任一牌区里）有没有牌
local function hasCard(player)
    for _, zone in ipairs(player:getZones()) do
        if zone:count() > 0 then
            return true
        end
    end
    return false
end

---@param player Player
---@return Zone[] # 身上有牌的那些区
local function cardZones(player)
    return table.filter(player:getZones(), function (zone)
        return zone:count() > 0
    end)
end

Card '过河拆桥'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user and hasCard(player)
        end)
    end)
    : on('生效', function (cardEffect)
        local card = game:askCard(cardEffect.user, '过河拆桥', { zone = cardZones(cardEffect.target) }).card
        if not card then
            return
        end
        game:moveCard(card, '弃牌')
    end)
