-- 【八卦阵】（标准版）
-- 每当你需要使用或打出一张【闪】时，你可以进行一次判定，若结果为红色，视为你使用或打出了一张【闪】。

Card '八卦阵'
    : extends '防具牌'
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        local viewAs = owner:addViewAs('闪', card)
            : on('发动', function ()
                if game:askChoice(owner, '八卦阵', { '发动' }).choice == nil then
                    return
                end
                ---@type Judge?
                local judge = nil
                card:cast(function ()
                    judge = game:judge(owner, '八卦阵')
                end)
                return assert(judge).card?.color == '红'
            end)
        host:bindGC(viewAs)
    end)
