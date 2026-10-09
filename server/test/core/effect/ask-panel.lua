local lt = require 'test.ltest'

local cardId = 0

---@param game Game
---@param name string
---@return Card
local function newCard(game, name)
    cardId = cardId + 1
    return moe.card.create(game, name, 200000 + cardId)
end

---@return Game
---@return Player
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { './package/*', lt.cardSource },
    }
    return game, moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
end

---@param game Game
---@param replies AskPanel.Change[] # 按顺序给出的回复
local function answerWith(game, replies)
    local index = 0
    game:on('面板-询问', function ()
        index = index + 1
        if index > #replies then
            error('脚本里没有更多回复了', 2)
        end
        return replies[index]
    end)
end

lt.test('面板询问：开着收变化，到点确定为止', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '测试', true, { moveable = true, min = 0 })
        :row({ first, second }, '上')
        :row({}, '下')
    answerWith(game, {
        { moves = { { cards = first, row = 2 } } },
        { done = true },
    })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('两行', 2, #ask.rows)
    lt.assertEquals('第一行剩一张', 1, #ask.rows[1])
    lt.assertEquals('剩下的是第二张', second, ask.rows[1][1])
    lt.assertEquals('挪到了第二行', first, ask.rows[2][1])
    lt.assertEquals('没选牌', nil, ask.card)
    lt.assertEquals('面板照结果变形', first, panel.rows[2].cells[1].card)
end)

lt.test('面板询问：挑选型（min = 1 得选一张）', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '五谷', true, { min = 1, max = 1 }):row { first, second }
    answerWith(game, {
        { card = second },
        { done = true },
    })

    local ask = game:askPanel(player, '五谷', panel)

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('选中的那张', second, ask.card)
    lt.assertEquals('选中的全表', 1, #ask.cards)
    lt.assertEquals('各行没动', 2, #ask.rows[1])
end)

lt.test('面板询问：min = 0 时不必选就能确定', function ()
    local game, player = newGame()
    local first = newCard(game, '甲')
    local panel = moe.panel.create(game, '测试', true):row { first }
    answerWith(game, { { done = true } })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('没有选中的牌', nil, ask.card)
    lt.assertEquals('形状照旧', first, ask.rows[1][1])
end)

lt.test('面板询问：min = 1 没选就确定 ⇒ 拒收', function ()
    local game, player = newGame()
    local first = newCard(game, '甲')
    local panel = moe.panel.create(game, '五谷', true, { min = 1, max = 1 }):row { first }
    answerWith(game, { { done = true } })

    local ask = game:askPanel(player, '五谷', panel)

    lt.assertFailed('没成立', ask)
    lt.assertEquals('原因', '至少要选中 1 张牌', ask.err)
end)

lt.test('面板询问：一次选太多（max）⇒ 拒收', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '五谷', true, { min = 1, max = 1 }):row { first, second }
    answerWith(game, { { card = { first, second } } })

    local ask = game:askPanel(player, '五谷', panel)

    lt.assertEquals('原因', '至多选中 1 张牌', ask.err)
end)

lt.test('面板询问：没人表态（min = 0）⇒ 空答复成立', function ()
    local game, player = newGame()
    local first = newCard(game, '甲')
    local panel = moe.panel.create(game, '测试', true):row { first }

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('成立了', true, ask.success)
    lt.assertEquals('形状照旧', first, ask.rows[1][1])
end)

lt.test('面板询问：没人表态（要选牌又不许取消）⇒ 拒收', function ()
    local game, player = newGame()
    local first = newCard(game, '甲')
    local panel = moe.panel.create(game, '五谷', true, { min = 1, max = 1, cancelable = false }):row { first }

    local ask = game:askPanel(player, '五谷', panel)

    lt.assertEquals('原因', '这次询问必须给出答复', ask.err)
end)

lt.test('面板询问：不许移动的面板收到移动 ⇒ 拒收（面板保持原样）', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '五谷', true):row { first, second }
    answerWith(game, { { moves = { { cards = second, row = 1 } } } })

    local ask = game:askPanel(player, '五谷', panel)

    lt.assertEquals('原因', '这块面板不能移动牌', ask.err)
    lt.assertEquals('面板没动', first, panel.rows[1].cells[1].card)
end)

lt.test('面板询问：挪不在面板上的牌 ⇒ 拒收', function ()
    local game, player = newGame()
    local first   = newCard(game, '甲')
    local outside = newCard(game, '乙')
    local panel = moe.panel.create(game, '测试', true, { moveable = true }):row { first }
    answerWith(game, { { moves = { { cards = outside, row = 1 } } } })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('原因', '这块面板上没有这张牌', ask.err)
end)

lt.test('面板询问：挪被禁用的牌 ⇒ 拒收', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '测试', true, { moveable = true }):row { first, second }
    panel:disableCard(second)
    answerWith(game, { { moves = { { cards = second, row = 1 } } } })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('原因', '这张牌已经被禁用了', ask.err)
end)

lt.test('面板询问：行号不存在 ⇒ 拒收', function ()
    local game, player = newGame()
    local first = newCard(game, '甲')
    local panel = moe.panel.create(game, '测试', true, { moveable = true }):row { first }
    answerWith(game, { { moves = { { cards = first, row = 2 } } } })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('原因', '这块面板上没有第 2 行', ask.err)
end)

lt.test('面板询问：一条回复里有一条不合法 ⇒ 整条作废（合法的也不生效）', function ()
    local game, player = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local panel = moe.panel.create(game, '测试', true, { moveable = true })
        :row({ first }, '上')
        :row({ second }, '下')
    answerWith(game, {
        {
            moves = {
                { cards = first, row = 2 },
                { cards = second, row = 9 },
            },
        },
    })

    local ask = game:askPanel(player, '测试', panel)

    lt.assertEquals('原因', '这块面板上没有第 9 行', ask.err)
    lt.assertEquals('第一条也没生效', first, panel.rows[1].cells[1].card)
    lt.assertEquals('第二行还是原来那张', second, panel.rows[2].cells[1].card)
end)
