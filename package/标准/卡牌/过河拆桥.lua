-- 【过河拆桥】（标准版）
-- 出牌阶段，对一名区域里有牌的其他角色使用。你弃置其区域里的一张牌。
-- 其区域里你能看见的牌可以直接挑；看不见的（手牌）只能从那个区里随机弃一张。

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

Card '过河拆桥'
    : extends '锦囊牌'
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user and hasCard(player)
        end)
    end)
    : on('生效', function (cardEffect)
        local user   = cardEffect.user
        local target = cardEffect.target
        local cards  = {}
        local zones  = {}
        for _, zone in ipairs(target:getZones()) do
            local held = zone:list()
            if #held > 0 then
                if zone:isVisibleTo(user) then
                    table.move(held, 1, #held, #cards + 1, cards)
                else
                    zones[#zones + 1] = zone
                end
            end
        end

        local ask  = game:askCard(user, '过河拆桥', { cards = cards, zones = zones })
        local card = ask.card
        if not card and ask.zone then
            card = game.random:pick(ask.zone:list())
        end
        if not card then
            return
        end
        game:moveCard(card, '弃牌')
    end)
