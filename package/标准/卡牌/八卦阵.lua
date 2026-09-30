-- 【八卦阵】（标准版）
-- 每当你需要使用或打出一张【闪】时，你可以进行一次判定，若结果为红色，视为你使用或打出了一张【闪】。

Card '八卦阵'
    : extends '防具牌'
    : on('被动', function (card, zone)
        local owner = zone.owner
        if not owner then
            return
        end
        return owner:on('打出-装备替代', function (ask)
            local names = ask.condition?.names
            if not names or not table.contains(names, '闪') then
                return
            end
            if game:askChoice(owner, '八卦阵', { '发动' }).choice == nil then
                return
            end
            local judge = game:judge(owner, '八卦阵')
            local color = judge.card?.color
            if color == '红' then
                return game:createVirtualCard('闪')
            end
        end)
    end)
