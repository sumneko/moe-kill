-- 【夏侯惇】（标准版）：魏 · 男 · 体力上限 4

Hero '夏侯惇'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '刚烈' }

-- 【刚烈】当你受到伤害后，你可以进行判定：若结果不为红桃，则伤害来源选择一项：弃置两张手牌，或受到 1 点伤害。
Skill '刚烈'
    : on('被动', function (skill, host)
        local owner = skill.owner
        host:bindGC(owner:on('伤害-目标-生效后', function (damage)
            local from = damage.from
            if not from then
                return
            end
            skill:tryCast(function ()
                local judge = game:judge(owner, '刚烈')
                if judge.card?.suit == '红桃' then
                    return
                end
                -- 要两张手牌：给不满（张数不对）或干脆取消，都由他挨那 1 点伤害
                local cards = game:askCard(from, '刚烈', { zone = '手牌', min = 2, max = 2 }).cards
                if #cards == 2 then
                    game:moveCard(cards, '弃牌')
                    return
                end
                game:damage(owner, from, 1)
            end)
        end))
    end)
