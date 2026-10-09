-- 【大乔】（标准版）：吴 · 女 · 体力上限 3
-- 【流离】当你成为【杀】的目标时，你可以弃置一张牌并选择你攻击范围内为此【杀】合法目标（无距离限制）的一名角色：若如此做，该角色代替你成为此【杀】的目标。
-- 【国色】（你可以将一张方块牌当【乐不思蜀】使用）待「虚拟牌进判定区」的机制定了再做

Hero '大乔'
    : kingdom '吴'
    : sex '女'
    : hp(3)
    : skills { '流离' }

Skill '流离'
    : event('卡牌-目标-指定目标后', function (skill, useCard, target)
        local owner = skill.owner
        if target ~= owner or useCard.card.name ~= '杀' then
            return
        end
        -- 「此【杀】的合法目标」不判距离（底本那句「无距离限制」）；「攻击范围内」是另一条判据、要判
        local options = table.copy(useCard.useOptions or {})
        options.ignoreDistance = true
        local candidates = table.filter(game:getLegalTargets(useCard.user, useCard.card, options), function (player)
            return player ~= owner
               and owner:isInRange(player)
        end)
        if #candidates == 0 then
            return
        end
        local ask = game:askCardWithTarget(owner, '流离', {
            card = {
                zone = rule.ownZones,
                min  = 1,
                max  = 1,
            },
            target = {
                player = candidates,
            },
        })
        -- 没答 = 不发动（弃牌与转移是一件事的两半，不分开问）
        if not ask.target then
            return
        end
        skill:cast(function ()
            game:moveCard(ask.cards, '弃牌')
            -- 官方「转移」：取消此目标，再生成一个新目标加入目标列表
            useCard:removeTarget(owner)
            useCard:addTarget(ask.target)
        end)
    end)
