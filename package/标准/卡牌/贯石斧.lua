-- 【贯石斧】（标准版）
-- 当你使用的【杀】被【闪】抵消后，你可以弃置两张牌，令此【杀】依然造成伤害。
-- 攻击范围 3

Card '贯石斧'
    : extends '武器牌'
    : value('攻击范围', 3)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:on('效果-来源-被抵消', function (ask)
            if ask.reason ~= '杀' or ask.card?.name ~= '闪' then
                return
            end
            -- 可以弃置两张牌（斧子自己不能弃 —— 官方「用到一张装备牌的技能时不能操作该牌」）
            ---@type Card[]
            local candidates = {}
            local hand = owner:getZone('手牌')
            table.move(hand:list(), 1, hand:count(), #candidates + 1, candidates)
            for _, equipped in ipairs(owner.equipCards) do
                if equipped ~= card then
                    candidates[#candidates + 1] = equipped
                end
            end
            if #candidates < 2 then
                return
            end
            local discarded = game:askCard(owner, '贯石斧', { card = candidates, min = 2, max = 2 })
            if #discarded.cards < 2 then
                return
            end
            game:moveCard(discarded.cards, '弃牌')
            ask:cancel('贯石斧')
        end))
    end)
