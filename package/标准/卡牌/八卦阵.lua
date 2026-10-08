-- 【八卦阵】（标准版）
-- 每当你需要使用或打出一张【闪】时，你可以进行一次判定，若结果为红色，视为你使用或打出了一张【闪】。

Card '八卦阵'
    : extends '防具牌'
    : viewAs('闪', nil, function (ask)
        if game:askChoice(ask.to, '八卦阵', { '发动' }).choice == nil then
            return
        end
        local judge = game:judge(ask.to, '八卦阵')
        if judge.card?.color == '红' then
            return true
        end
    end)
