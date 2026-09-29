-- 【诸葛连弩】（标准版）
-- 出牌阶段，你可以使用任意数量的【杀】。
-- 攻击范围 1

Card '诸葛连弩'
    : extends '武器牌'
    : value('攻击范围', 1)
    : on('被动', function (card, zone)
        local owner = assert(zone.owner)
        ---@type fun()? # 当前这个出牌阶段上补记的那笔账
        local undoCurrent = nil

        local unsubscribe = game:on('阶段-开始', function (phase)
            if phase.name == '出牌' and phase.player == owner then
                undoCurrent = phase:addLimit('杀', 1000)
            end
        end)

        local current = game.phase
        if current and current.name == '出牌' and current.player == owner then
            undoCurrent = current:addLimit('杀', 1000)
        end

        return function ()
            unsubscribe()
            if undoCurrent then
                undoCurrent()
                undoCurrent = nil
            end
        end
    end)
