-- 【青釭剑】（标准版）
-- 锁定技，当你使用【杀】指定一名角色为目标后，无视其防具。
-- 攻击范围 2

Card '青釭剑'
    : extends '武器牌'
    : value('攻击范围', 2)
    : on('被动', function (card, zone)
        local owner = zone.owner
        if not owner then
            return
        end
        -- 逐目标压（指定目标后）：窗口不随剑 / 使用者消失（官方 §1 司马懿条）
        return owner:on('卡牌-来源-指定目标后', function (useCard, target)
            if useCard.card.name ~= '杀' then
                return
            end
            -- 兜底：这次使用收场（含半路取消）时连带把状态删掉
            useCard:bindGC(target:addBuff('防具无效', useCard))
        end)
    end)

Buff '防具无效'
    : on('获得', function (buff)
        buff:bindGC(buff.owner:getZone('防具')?:disable())
        -- 载荷是挂它的那次使用（剑那张牌给的）
        local useCard = buff.payload
        buff:bindGC(buff.owner:on('效果-收尾', function (effect)
            if effect.kind ~= 'cardEffect' then
                return
            end
            ---@cast effect CardEffect
            if effect.useCard == useCard then
                buff:remove()
            end
        end))
    end)
