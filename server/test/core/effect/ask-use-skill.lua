local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-use-skill-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '技能.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Skill '制衡'
    : on('使用', function (cast)
        cast:setTag('跑过', cast.source.name)
    end)
Skill '仁德'
    : cards { zone = '手牌', max = 2 }
    : targets { max = 2, filter = function (player, skill)
        return player ~= skill.owner
    end }
    : on('使用', function (cast)
        cast:setTag('拿过', #cast.use.cards)
        cast:setTag('目标数', #cast.use.targets)
    end)
Skill '突袭'
    : cards { zone = '手牌' }
    : targets { filter = function (player, skill)
        return player ~= skill.owner
    end }
    : on('使用', function (cast)
        cast:setTag('拿过', #cast.use.cards)
    end)
Skill '双目标'
    : targets { min = 2, filter = function (player, skill)
        return player ~= skill.owner
    end }
    : on('使用', function (cast)
        cast:setTag('目标数', #cast.use.targets)
    end)
Skill '限一次'
    : limit('出牌', 1)
    : on('使用', function (cast)
        cast:setTag('跑过', cast.source.name)
    end)
Skill '奸雄'
]])
    assert(ok, err)
end

---@param count? integer # 坐几个人（默认 1）
---@return Game
local function newGame(count)
    return moe.game.create {
        seats    = count or 1,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*', lt.cardSource },
        packages = { '探针' },
    }
end

---@param game Game
---@return Player
local function newPlayer(game)
    return moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
end

lt.test('要一次技能使用：候选只看有主动发动钩子的技能', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    player:addSkill('奸雄')
    game:on('技能-询问', function (ask)
        return nil
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('种类标识', 'askUseSkill', ask.kind)
    lt.assertEquals('缘由原样带着', '出牌', ask.reason)
    lt.assertEquals('只列出有钩子的那个', 1, #ask.options)
    lt.assertEquals('就是它', '制衡', ask.options[1].skill.name)
end)

lt.test('要一次技能使用：答了就发动，归因在技能名下', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    game:on('技能-询问', function (ask)
        return { skill = ask.options[1].skill }
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('答复读得到', '制衡', assert(ask.skill).name)
    local cast = assert(ask.cast, '入口应该发动它')
    lt.assertEquals('就是一次发动', 'cast', cast.kind)
    lt.assertEquals('归因到技能名下', '制衡', cast.source?.name)
    lt.assertEquals('发动者是他', player, cast.from)
    lt.assertEquals('钩子跑过了', '制衡', cast:getTag('跑过'))
    lt.assertEquals('再调一次不会发动第二遍', cast, ask:use())
end)

lt.test('要一次技能使用：答复不是他身上的技能就拒收', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    local other = newPlayer(game)
    other:addSkill('制衡')
    game:on('技能-询问', function ()
        return { skill = other:getSkills()[1] }
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('没拿到答复', nil, ask.skill)
    lt.assertEquals('原因', '答复不是可以发动的技能', ask.err)
    lt.assertEquals('也没发动', nil, ask.cast)
end)

lt.test('要一次技能使用：没人应答就没有答复，也不算失败', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    lt.clearErrors()

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('没有答复', nil, ask.skill)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('也没发动', nil, ask.cast)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('只到 apply：不等它、也不替你发动出去', function ()
    local game   = newGame()
    local player = newPlayer(game)
    player:addSkill('制衡')
    game:on('技能-询问', function (ask)
        return { skill = ask.options[1].skill }
    end)

    local ask = game:startAskUseSkill(player, '出牌')
    lt.assertEquals('刚起完：候选都还没算', 0, #ask.options)

    ask:await()
    lt.assertEquals('等它才结：答复到手', '制衡', assert(ask.skill).name)
    lt.assertEquals('不等你点头就不发动', nil, ask.cast)

    ask:use()
    lt.assertEquals('发动了才有那次发动', '制衡', assert(ask.cast).source?.name)
end)

lt.test('要一次技能使用：选项带上前置（能挑的牌与目标、各自的区间）', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    player:addSkill('仁德')
    player:addSkill('制衡')
    local first  = game:createCard('杀')
    local second = game:createCard('闪')
    assert(player:getZone('手牌')):accept({ first, second })

    game:on('技能-询问', function ()
        return nil
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('两个技能都进选项', 2, #ask.options)
    local renDe = ask.options[1]
    lt.assertEquals('第一个是仁德', '仁德', renDe.skill.name)
    local cards = assert(renDe.cards, '仁德该带牌那半')
    lt.assertEquals('能挑的手牌都在', 2, #cards.legal)
    lt.assertEquals('张数区间', '1,2', cards.min .. ',' .. cards.max)
    local targets = assert(renDe.targets, '仁德该带目标那半')
    lt.assertEquals('能挑的目标只有别人', 1, #targets.legal)
    lt.assertEquals('就是他', other, targets.legal[1])
    lt.assertEquals('个数区间', '1,2', targets.min .. ',' .. targets.max)
    local zhiheng = ask.options[2]
    lt.assertEquals('制衡没声明牌', nil, zhiheng.cards)
    lt.assertEquals('制衡没声明目标', nil, zhiheng.targets)
end)

lt.test('要一次技能使用：前置只写 min ⇒ 上限跟 min 一样', function ()
    local game   = newGame(3)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    local third  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    game.desk:sit(3, third)
    player:addSkill('双目标')

    game:on('技能-询问', function ()
        return nil
    end)

    local ask     = game:askUseSkill(player, '出牌')
    local option  = assert(ask.options[1])
    local targets = assert(option.targets)
    lt.assertEquals('区间就是 2、2', '2,2', targets.min .. ',' .. targets.max)
end)

lt.test('要一次技能使用：凑不齐前置的技能不进选项', function ()
    local game   = newGame()
    local player = newPlayer(game)
    game.desk:sit(1, player)
    player:addSkill('仁德')
    player:addSkill('制衡')
    game:on('技能-询问', function ()
        return nil
    end)

    local noCards = game:askUseSkill(player, '出牌')
    lt.assertEquals('没手牌 ⇒ 仁德不进选项', 1, #noCards.options)
    lt.assertEquals('制衡还在', '制衡', noCards.options[1].skill.name)

    assert(player:getZone('手牌')):accept(game:createCard('杀'))
    local noTarget = game:askUseSkill(player, '出牌')
    lt.assertEquals('只有自己 ⇒ 仁德照样不进选项', 1, #noTarget.options)
end)

lt.test('要一次技能使用：答复带牌与目标，发动时交给钩子', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    player:addSkill('仁德')
    local first  = game:createCard('杀')
    local second = game:createCard('闪')
    assert(player:getZone('手牌')):accept({ first, second })

    game:on('技能-询问', function ()
        return { skill = player:getSkills()[1], cards = { first, second }, targets = other }
    end)

    local ask = game:askUseSkill(player, '出牌')

    lt.assertEquals('答复的技能读得到', '仁德', assert(ask.skill).name)
    local cast = assert(ask.cast, '入口应该发动它')
    lt.assertEquals('钩子收到两张牌', 2, cast:getTag('拿过'))
    lt.assertEquals('钩子收到一个目标', 1, cast:getTag('目标数'))
end)

lt.test('要一次技能使用：答复的牌不合法 ⇒ 拒收', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    player:addSkill('仁德')
    local hand1  = game:createCard('杀')
    local hand2  = game:createCard('闪')
    assert(player:getZone('手牌')):accept({ hand1, hand2 })
    local outside = game:createCard('桃')

    local index = 0
    game:on('技能-询问', function ()
        index = index + 1
        if index == 1 then
            return { skill = player:getSkills()[1], cards = { hand1, hand2, outside }, targets = other }
        end
        if index == 2 then
            return { skill = player:getSkills()[1], cards = { hand1, hand1 }, targets = other }
        end
        return { skill = player:getSkills()[1], cards = outside, targets = other }
    end)

    local many = game:askUseSkill(player, '出牌')
    lt.assertEquals('超张数 ⇒ 拒收', '至多给 2 张牌', many.err)

    local dup = game:askUseSkill(player, '出牌')
    lt.assertEquals('重复 ⇒ 拒收', '答复的牌重复了', dup.err)

    local away = game:askUseSkill(player, '出牌')
    lt.assertEquals('不在能挑的牌里 ⇒ 拒收', '答复不在可选项里', away.err)
end)

lt.test('要一次技能使用：答复的目标不合法 ⇒ 拒收', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    player:addSkill('仁德')
    local hand1 = game:createCard('杀')
    assert(player:getZone('手牌')):accept(hand1)

    local index = 0
    game:on('技能-询问', function ()
        index = index + 1
        if index == 1 then
            return { skill = player:getSkills()[1], cards = hand1, targets = player }
        end
        return { skill = player:getSkills()[1], cards = hand1, targets = { other, other } }
    end)

    local selfTarget = game:askUseSkill(player, '出牌')
    lt.assertEquals('选中被排除的自己 ⇒ 拒收', '答复的目标不在可选项里', selfTarget.err)

    local dup = game:askUseSkill(player, '出牌')
    lt.assertEquals('目标重复 ⇒ 拒收', '答复的目标重复了', dup.err)
end)

lt.test('要一次技能使用：没声明前置的答复不该带牌与目标，且必须是一张表', function ()
    local game   = newGame()
    local player = newPlayer(game)
    game.desk:sit(1, player)
    player:addSkill('制衡')

    local index = 0
    game:on('技能-询问', function ()
        index = index + 1
        if index == 1 then
            return { skill = player:getSkills()[1], cards = game:createCard('杀') }
        end
        return '制衡'
    end)

    local withCards = game:askUseSkill(player, '出牌')
    lt.assertEquals('不该给牌', '这次答复不该给牌', withCards.err)

    local notTable = game:askUseSkill(player, '出牌')
    lt.assertEquals('答复必须是一张表', '答复必须是一张表（`{ skill = ... }`）', notTable.err)
end)

lt.test('要一次技能使用：min / max 不写就是 1 / 1', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    player:addSkill('突袭')
    local first  = game:createCard('杀')
    local second = game:createCard('闪')
    assert(player:getZone('手牌')):accept({ first, second })

    local step = 0
    game:on('技能-询问', function ()
        step = step + 1
        if step == 1 then
            return nil -- 先只看选项
        end
        if step == 2 then
            return { skill = player:getSkills()[1], cards = { first, second }, targets = other }
        end
        return { skill = player:getSkills()[1], cards = first, targets = other }
    end)

    local peek   = game:askUseSkill(player, '出牌')
    local option = assert(peek.options[1])
    local cards  = assert(option.cards)
    lt.assertEquals('张数默认 1 / 1', '1,1', cards.min .. ',' .. cards.max)
    local targets = assert(option.targets)
    lt.assertEquals('目标默认 1 / 1', '1,1', targets.min .. ',' .. targets.max)

    local many = game:askUseSkill(player, '出牌')
    lt.assertEquals('给 2 张超默认上限 ⇒ 拒收', '至多给 1 张牌', many.err)

    local one = game:askUseSkill(player, '出牌')
    lt.assertEquals('给 1 张就过', '突袭', assert(one.skill).name)
    lt.assertEquals('钩子收到 1 张', 1, assert(one.cast):getTag('拿过'))
end)

lt.test('要一次技能使用：自己的阶段里次数用尽就不进选项', function ()
    local game   = newGame()
    local player = newPlayer(game)
    local skill  = player:addSkill('限一次')
    game:on('技能-询问', function (ask)
        local option = ask.options[1]
        if not option then
            return nil
        end
        return { skill = option.skill }
    end)

    local phase <close> = game:enterPhase(player, '出牌')

    local first = game:askUseSkill(player, '出牌')
    lt.assertEquals('第一次能发动', skill, first.skill)
    lt.assertEquals('账记在自己这个阶段上', 1, phase:getUseCount(skill.def.fullName))

    local second = game:askUseSkill(player, '出牌')
    lt.assertEquals('次数用尽 ⇒ 不进选项', 0, #second.options)
    lt.assertEquals('也就没发动', nil, second.skill)
end)

lt.test('要一次技能使用：不在自己的阶段里就不记账', function ()
    local game   = newGame(2)
    local player = newPlayer(game)
    local other  = newPlayer(game)
    game.desk:sit(1, player)
    game.desk:sit(2, other)
    local skill  = player:addSkill('限一次')
    game:on('技能-询问', function (ask)
        return { skill = ask.options[1].skill }
    end)

    local phase <close> = game:enterPhase(other, '出牌') -- 阶段是别人的

    local ask = game:askUseSkill(player, '出牌')
    lt.assertEquals('照常能发动', skill, ask.skill)
    lt.assertEquals('不记在别人的阶段上', 0, phase:getUseCount(skill.def.fullName))
end)
