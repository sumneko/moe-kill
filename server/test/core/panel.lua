local lt = require 'test.ltest'

local cardId = 0

---@param game Game
---@param name string
---@return Card
local function newCard(game, name)
    cardId = cardId + 1
    return moe.card.create(game, name, 100000 + cardId)
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

lt.test('面板：行按顺序摆好（行号从 1 起）', function ()
    local game = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local third  = newCard(game, '丙')
    local panel = moe.panel.create(game, '测试', true)
        :row({ first, second }, '上')
        :row({ third }, '下')

    lt.assertEquals('两行', 2, #panel.rows)
    lt.assertEquals('行标题', '上', panel.rows[1].title)
    lt.assertEquals('第一行第一格', first, panel.rows[1].cells[1].card)
    lt.assertEquals('第一行第二格', second, panel.rows[1].cells[2].card)
    lt.assertEquals('第二行第一格', third, panel.rows[2].cells[1].card)
    lt.assertEquals('面板上的牌按行序', 3, #panel:cards())
    lt.assertEquals('第二张还在', second, panel:cards()[2])
    lt.assertEquals('含有这一张', true, panel:contains(second))
end)

lt.test('面板：禁用只是标记（牌仍留在行里），标记照读', function ()
    local game = newGame()
    local first   = newCard(game, '甲')
    local second  = newCard(game, '乙')
    local outside = newCard(game, '丙')
    local panel = moe.panel.create(game, '测试'):row { first, second }

    lt.assertEquals('禁用成功', true, panel:disableCard(second))
    lt.assertEquals('被禁用了', true, panel:isDisabled(second))
    lt.assertEquals('没被禁用', false, panel:isDisabled(first))
    lt.assertEquals('牌没被挪走', 2, #panel:cards())
    lt.assertEquals('还在原处', second, panel.rows[1].cells[2].card)
    lt.assertEquals('不在面板上的禁不了', false, panel:disableCard(outside))

    panel:addMark(second, '${hero:张三}')
    lt.assertEquals('标记挂上了', '${hero:张三}', panel:marks(second)[1])
    lt.assertEquals('没标记的是空', 0, #panel:marks(first))
    lt.assertEquals('不在面板上的标记不了', 0, #panel:marks(outside))
end)

lt.test('面板：摘一格再放到行尾（搬动就靠这两个）', function ()
    local game = newGame()
    local first  = newCard(game, '甲')
    local second = newCard(game, '乙')
    local third  = newCard(game, '丙')
    local panel = moe.panel.create(game, '测试', true, { moveable = true })
        :row { first, second }
        :row { third }

    local cell = panel:takeOut(first)
    lt.assertEquals('摘下来了', false, panel:contains(first))
    lt.assertEquals('第一行剩一张', 1, #panel.rows[1].cells)

    panel:appendCell(panel.rows[2], assert(cell))
    lt.assertEquals('第二行接上了', 2, #panel.rows[2].cells)
    lt.assertEquals('接在该行末尾', first, panel.rows[2].cells[2].card)
    lt.assertEquals('牌没多没少', 3, #panel:cards())
    lt.assertEquals('按行序读出来是新形状', first, panel:cards()[3])
end)

lt.test('面板：牌面按可见性遮（布局本身人人可见）', function ()
    local game, viewer = newGame()
    local other = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })

    lt.assertEquals('默认都看得见', true, moe.panel.create(game, '测试'):isVisibleTo(viewer))
    lt.assertEquals('说了只给某人', true, moe.panel.create(game, '测试', viewer):isVisibleTo(viewer))
    lt.assertEquals('别人看不见牌面', false, moe.panel.create(game, '测试', viewer):isVisibleTo(other))
    lt.assertEquals('藏起来谁都看不见', false, moe.panel.create(game, '测试', false):isVisibleTo(viewer))
end)
