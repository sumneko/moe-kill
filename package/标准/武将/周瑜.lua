-- 【周瑜】（标准版）：吴 · 男 · 体力上限 3

Hero '周瑜'
    : kingdom '吴'
    : sex '男'
    : hp(3)
    : skills { '英姿', '反间' }

-- 【英姿】摸牌阶段，你可以多摸一张牌。
Skill '英姿'
    : auto(true)
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '摸牌' then
            return
        end
        skill:tryCast(function ()
            phase:bindGC(skill.owner:addAttr('摸牌数', 1))
        end)
    end)

-- 【反间】出牌阶段限一次，你可以令一名其他角色选择一种花色，然后正面朝上获得你的一张手牌。若此牌花色与其所选花色不同，你对其造成 1 点伤害。
Skill '反间'
    : limit('出牌', 1)
    : cards { zone = '手牌', min = 1, max = 1 }
    : targets {
        filter = function (player, skill)
            return player ~= skill.owner
        end,
    }
    : on('使用', function (cast)
        local target = cast.use.targets[1]
        local card   = cast.use.cards[1]
        if not target or not card then
            return
        end
        -- 不答复 = 没选花色 ⇒ 跟任何选项都对不上 ⇒ 一定算「花色不同」
        local chosen = game:askChoice(target, '反间', { '${红桃}', '${方块}', '${黑桃}', '${梅花}' }).choice
        -- 正面朝上给出去 = 这次搬动对所有人可见
        game:moveCard(card, target:getZone('手牌'), true)
        if chosen ~= '${' .. (card.suit or '') .. '}' then
            game:damage(cast.from, target, 1, card)
        end
    end)
