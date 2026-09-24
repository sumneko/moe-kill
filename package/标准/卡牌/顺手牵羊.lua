-- 【顺手牵羊】（标准版）
-- 出牌阶段，对距离 1 以内的一名区域里有牌的其他角色使用。你获得其区域里的一张牌。
-- 服务器侧看得见所有牌（隐瞒是协议层的事）⇒ 目标的每个区都逐张当候选，挑中哪张就获得哪张。

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

Card '顺手牵羊'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        local user = target.user
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= user
                and hasCard(player)
                and game.desk:getDistance(user, player) <= 1
        end)
    end)
    : on('生效', function (cardEffect)
        local card = game:askCard(cardEffect.user, '顺手牵羊', { zone = cardEffect.target:getZones() }).card
        if not card then
            return
        end
        game:moveCard(card, cardEffect.user:getZone('手牌'))
    end)
