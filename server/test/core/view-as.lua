local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[]
local function newGame(count)
    local game = moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { './package/*', lt.cardSource },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', { min = -999999, max = 999999, simple = true })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        players[i] = player
    end
    return game, players
end

lt.test('视为声明：挂上就在列表里，名字与宿主读得到', function ()
    local _, players = newGame(2)
    local viewAs = players[1]:addViewAs('闪')

    lt.assertEquals('视为的牌名', '闪', viewAs.name)
    lt.assertEquals('宿主', players[1], viewAs.owner)
    local list = players[1]:getViewAsList()
    lt.assertEquals('列表里有一条', 1, #list)
    lt.assertEquals('就是它', viewAs, list[1])
    lt.assertEquals('别人身上没有', 0, #players[2]:getViewAsList())
end)

lt.test('视为声明：`on` 链式返回自己', function ()
    local _, players = newGame(2)
    local viewAs = players[1]:addViewAs('闪')
    local chained = viewAs:on('发动', function () end)

    lt.assertEquals('返回的是它自己', viewAs, chained)
end)

lt.test('视为声明：快照按声明顺序', function ()
    local _, players = newGame(2)
    local first  = players[1]:addViewAs('闪')
    local second = players[1]:addViewAs('杀')

    local list = players[1]:getViewAsList()
    lt.assertEquals('两条', 2, #list)
    lt.assertEquals('先声明在前', first, list[1])
    lt.assertEquals('后声明在后', second, list[2])
end)

lt.test('视为声明：撤销从列表里摘掉，且幂等', function ()
    local _, players = newGame(2)
    local viewAs = players[1]:addViewAs('闪')

    viewAs:remove()
    lt.assertEquals('列表空了', 0, #players[1]:getViewAsList())
    viewAs:remove()
    lt.assertEquals('再撤一次也不出错', 0, #players[1]:getViewAsList())
end)

lt.test('视为声明：第一个说成立的就胜出，后面的不再跑', function ()
    local game, players = newGame(2)
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    ---@type string[]
    local trace = {}
    local viewAs = players[1]:addViewAs('闪')
        : on('发动', function ()
            trace[#trace + 1] = '第一'
        end)
        : on('发动', function ()
            trace[#trace + 1] = '第二'
            return true
        end)
        : on('发动', function ()
            trace[#trace + 1] = '第三'
            return true
        end)

    local produced = assert(viewAs:tryProduce(ask), '该产出')
    lt.assertEquals('造出的就是声明的那张牌', '闪', produced.name)
    lt.assertEquals('是虚拟牌', true, produced.virtual)
    lt.assertEquals('第三个没被跑', '第一,第二', table.concat(trace, ','))
end)

lt.test('视为声明：都没说成立就是没产出', function ()
    local game, players = newGame(2)
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    local viewAs = players[1]:addViewAs('闪')
        : on('发动', function ()
            return nil
        end)

    lt.assertEquals('没产出', nil, viewAs:tryProduce(ask))
end)

lt.test('视为声明：没登记钩子时默认成立，照牌名造一张没有素材的牌', function ()
    local game, players = newGame(2)
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    local viewAs = players[1]:addViewAs('闪')

    local produced = assert(viewAs:tryProduce(ask), '该产出')
    lt.assertEquals('照声明的牌名造', '闪', produced.name)
    lt.assertEquals('没有素材', 0, #produced.subcards)
end)

lt.test('视为声明：素材不够就不试，连问都不问', function ()
    local game, players = newGame(2)
    local hand = assert(players[1]:getZone('手牌'))
    hand:accept(game:createCard('闪'))

    ---@type integer
    local asked = 0
    game:on('卡牌-询问', function ()
        asked = asked + 1
        return { card = hand:list()[1] }
    end)

    local viewAs = players[1]:addViewAs('杀', nil, { zone = '手牌', min = 2, max = 2 })
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    lt.assertEquals('没产出', nil, viewAs:tryProduce(ask))
    lt.assertEquals('没问过玩家', 0, asked)
end)

lt.test('视为声明：条件一张都筛不出来时也跳过', function ()
    local game, players = newGame(2)
    local hand = assert(players[1]:getZone('手牌'))
    hand:accept(game:createCard('闪', '黑桃', 2))

    local viewAs = players[1]:addViewAs('杀', nil, { zone = '手牌', color = '红', min = 1, max = 1 })
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    lt.assertEquals('没产出', nil, viewAs:tryProduce(ask))
end)

lt.test('视为声明：素材收齐就造牌，牌带着那几张子牌（牌本身不动）', function ()
    local game, players = newGame(2)
    local hand   = assert(players[1]:getZone('手牌'))
    local first  = game:createCard('闪', '红桃', 2)
    local second = game:createCard('桃', '红桃', 3)
    hand:accept(first)
    hand:accept(second)
    game:on('卡牌-询问', function ()
        return { card = { first, second } }
    end)

    local viewAs = players[1]:addViewAs('杀', nil, { zone = '手牌', min = 2, max = 2 })
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    local produced = assert(viewAs:tryProduce(ask), '该产出')
    lt.assertEquals('照声明的牌名造', '杀', produced.name)
    lt.assertEquals('是虚拟牌', true, produced.virtual)
    lt.assertEquals('子牌带了两张', 2, #produced.subcards)
    lt.assertEquals('第一张', first, produced.subcards[1])
    lt.assertEquals('第二张', second, produced.subcards[2])
    lt.assertEquals('素材自己没动（去哪由搬牌的人定）', 2, hand:count())
end)

lt.test('视为声明：素材条件按牌面筛（只要红色的）', function ()
    local game, players = newGame(2)
    local hand  = assert(players[1]:getZone('手牌'))
    local red   = game:createCard('闪', '红桃', 2)
    local black = game:createCard('闪', '黑桃', 2)
    hand:accept(red)
    hand:accept(black)
    ---@type integer
    local candidates = 0
    game:on('卡牌-询问', function (ask)
        local options = assert(ask.options)
        candidates = #options
        return { card = options[1].card }
    end)

    local viewAs = players[1]:addViewAs('杀', nil, { zone = '手牌', color = '红', min = 1, max = 1 })
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    local produced = assert(viewAs:tryProduce(ask), '该产出')
    lt.assertEquals('收的是红色那张', red, produced.subcards[1])
    lt.assertEquals('素材候选只剩红色那张', 1, candidates)
end)

lt.test('视为声明：素材没给够就不成立', function ()
    local game, players = newGame(2)
    local hand = assert(players[1]:getZone('手牌'))
    hand:accept(game:createCard('闪'))
    hand:accept(game:createCard('桃'))

    local viewAs = players[1]:addViewAs('杀', nil, { zone = '手牌', min = 2, max = 2 })
    local ask = moe.askCard.create { game = game, to = players[1], reason = '测试' }

    lt.assertEquals('没人答 ⇒ 没产出', nil, viewAs:tryProduce(ask))
end)

lt.test('视为声明：关联的来源读得到，不传就是空', function ()
    local game, players = newGame(2)
    local source = game:createCard('闪')

    lt.assertEquals('关联就是给的那个', source, players[1]:addViewAs('杀', source).source)
    lt.assertEquals('不传就是空', nil, players[1]:addViewAs('闪').source)
end)
