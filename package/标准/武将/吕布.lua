-- 【吕布】（标准版）：群 · 男 · 体力上限 4

Hero '吕布'
    : kingdom '群'
    : sex '男'
    : hp(4)
    : skills { '无双' }

-- 【无双】锁定技，当你使用【杀】指定目标后，其使用【闪】抵消此【杀】的方式改为需连续使用两张【闪】；
--         当你使用【决斗】指定目标后，或当你成为【决斗】的目标后，你令其打出【杀】响应此【决斗】的方式改为需连续打出两张【杀】。

--- 让他「在这次使用里响应时」要连出两张：订阅挂到这次使用上（活到这次使用结束 ⇒ 中途失去技能也不中断）
---@param useCard UseCard
---@param other Player # 谁要多打一张
---@param name string # 要他打出来的牌名
local function requireTwo(useCard, other, name)
    useCard:bindGC(game:on('卡牌-答复后', function (ask)
        if ask.responseOptions?.responseTo ~= useCard or ask.to ~= other then
            return
        end
        -- 追一张：拿不出来就吊销这次响应 ——【杀】照常造成伤害、【决斗】那边判「没打出来」；
        -- 吊销发生在「被响应」那两段时机之前 ⇒ 青龙偃月刀 / 贯石斧不会被误触发
        if not game:askPlayCard(other, ask.reason, { name = name }).card then
            ask:cancel('无双')
        end
    end))
end

Skill '无双'
    : tags '锁定技'
    : event('卡牌-来源-指定目标后', function (skill, useCard, target)
        local name = useCard.card.name
        if name == '杀' then
            requireTwo(useCard, target, '闪')
        elseif name == '决斗' then
            requireTwo(useCard, target, '杀')
        end
    end)
    : event('卡牌-目标-指定目标后', function (skill, useCard, target)
        -- 我成为【决斗】的目标：要多打一张的是使用者
        if useCard.card.name == '决斗' then
            requireTwo(useCard, useCard.user, '杀')
        end
    end)
