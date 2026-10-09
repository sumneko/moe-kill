-- 【貂蝉】（标准版）：群 · 女 · 体力上限 3

Hero '貂蝉'
    : kingdom '群'
    : sex '女'
    : hp(3)
    : skills { '离间', '闭月' }

-- 【离间】出牌阶段限一次，你可以弃置一张牌并选择两名其他男性角色，后选择的角色视为对先选择的角色使用了一张不能被【无懈可击】的【决斗】。
Skill '离间'
    : limit('出牌', 1)
    : cards { zone = rule.ownZones, min = 1, max = 1 }
    : targets {
        min    = 2,
        max    = 2,
        filter = function (player, skill)
            return player ~= skill.owner and player.sex == '男'
        end,
    }
    : on('使用', function (cast)
        -- 顺序有语义：先选的挨打、后选的视为使用者
        local victim = cast.use.targets[1]
        local user   = cast.use.targets[2]
        if not victim or not user then
            return
        end
        game:moveCard(cast.use.cards, '弃牌')
        game:useCard(user, game:createVirtualCard('决斗'), victim, { unnullifiable = true })
    end)

-- 【闭月】结束阶段开始时，你可以摸一张牌。
Skill '闭月'
    : auto(true)
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '结束' then
            return
        end
        skill:tryCast(function ()
            skill.owner:draw(1)
        end)
    end)
