-- 【诸葛连弩】（标准版）
-- 出牌阶段，你可以使用任意数量的【杀】。
-- 攻击范围 1

Card '诸葛连弩'
    : extends '武器牌'
    : value('攻击范围', 1)
    : on('被动', function (card, zone)
        local owner = assert(zone.owner)
        ---@type fun()?
        local undoCurrent = nil

        local function refresh(phase)
            if phase?.name == '出牌' then
                undoCurrent = phase?:addLimit('杀', 1000)
            end
        end

        local unsubscribe = owner:on('阶段-开始', refresh)

        refresh(owner:currentPhase())

        return function ()
            unsubscribe()
            undoCurrent?()
        end
    end)
