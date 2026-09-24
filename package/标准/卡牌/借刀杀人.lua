-- 【借刀杀人】（标准版）
-- 出牌阶段，对装备区里有武器牌的一名其他角色使用。你指定其攻击范围内的一名其他角色：
-- 该角色需对其使用一张【杀】，否则将其装备区里的武器牌交给你。
-- 被指定的那名角色不是这张牌的目标（不进 targets，不触发「成为目标」类技能）。

---@param player Player
---@return Card? # 装备区里的武器牌（按分类认，不认槽位名）
local function weaponOf(player)
    local equip = assert(player:getZone('装备'), '装备区由内核建好')
    for _, card in ipairs(equip:list()) do
        local def = game:getCard(card.name)
        if def and def:isKind('武器') then
            return card
        end
    end
    return nil
end

---@param player Player # 被借刀者
---@return Player[] # 他能打到的人（攻击范围内的其他存活角色）
local function reachable(player)
    local range = player:getAttr('攻击范围')
    return table.filter(game.desk.alivePlayers, function (other)
        return other ~= player and distance(player, other) <= range
    end)
end

Card '借刀杀人'
    : extends '锦囊牌'
    : on('获取目标', function (plan)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= plan.user
                and weaponOf(player) ~= nil
                and #reachable(player) > 0
        end)
    end)
    : on('生效', function (cardEffect)
        local user   = cardEffect.user
        local holder = cardEffect.target
        local weapon = weaponOf(holder)
        if not weapon then
            return
        end

        local candidates = reachable(holder)
        local chosen     = game:ask(user, '借刀杀人', { candidates = candidates }).reply
        if not table.contains(candidates, chosen) then
            chosen = nil
        end

        if chosen then
            local use = game:askUseCard(holder, '借刀杀人', { name = '杀', target = chosen })
            if use.card then
                game:useCard(holder, use.card, use.targets or {})
                return
            end
        end

        game:moveCard(weapon, user:getZone('手牌'))
    end)
