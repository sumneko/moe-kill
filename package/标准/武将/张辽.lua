-- 【张辽】（标准版）：魏 · 男 · 体力上限 4

Hero '张辽'
    : kingdom '魏'
    : sex '男'
    : hp(4)
    : skills { '突袭' }

-- 【突袭】摸牌阶段，你可以改为获得至多两名其他角色的各一张手牌。
Skill '突袭'
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '摸牌' then
            return
        end
        local victims = table.filter(game.desk.alivePlayers, function (player)
            return player ~= skill.owner and player:getZone('手牌'):count() > 0
        end)
        if #victims == 0 then
            return
        end
        -- 不问「发不发动」：选几个就是几个，一个都不选 = 不发动（照常摸牌）
        local ask = game:askPlayer(skill.owner, '突袭', { player = victims, min = 0, max = 2 })
        if #ask.players == 0 then
            return
        end
        skill:cast(function ()
            -- 「改为」= 本阶段不摸牌（摸牌数的下界是 0，减一个大数就是清零）
            phase:bindGC(skill.owner:addAttr('摸牌数', -1000))
            for _, victim in ipairs(ask.players) do
                -- 盲取：不看牌面，从他的手牌里随机拿一张
                local hand = victim:getZone('手牌')
                local card = hand:list()[game.random:nextInt(1, hand:count())]
                game:moveCard(card, skill.owner:getZone('手牌'))
            end
        end)
    end)
