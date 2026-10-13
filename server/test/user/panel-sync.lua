local lt      = require 'test.ltest'
local support = require 'test.user.support'

--- 收「发给某条连接的」某一类通知（返回攒下来的 params 与撤销函数）
---@param method string
---@param front Client
---@return table[]
---@return fun()
local function collect(method, front)
    ---@type table[]
    local got = {}
    local undo = moe.client.register(method, function (client, params)
        if client == front then
            got[#got + 1] = params
        end
    end)
    return got, undo
end

---@async
lt.test('面板下行：建出来就广播 Panel.Create（按各人的牌视图发号）', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local first  = support.giveCard(game, me, '杀', '黑桃', 7)
    local second = support.giveCard(game, me, '闪', '红桃', 2)

    local got, undo = collect('Panel.Create', front)
    local _ <close> = undo

    local panel = moe.panel.create(game, '测试', true, { moveable = true, min = 1, max = 1 })
        :row({ first, second }, '上')
    moe.await.sleep(0)

    lt.assertEquals('一条创建', 1, #got)
    local proto = assert(assert(got[1]).panel)
    lt.assertEquals('面板号是它自己的', panel.id, proto.id)
    lt.assertEquals('名字带上了', '测试', proto.name)
    lt.assertEquals('说了可以移', true, proto.moveable)
    lt.assertEquals('个数区间带上', '1,1', proto.min .. ',' .. proto.max)
    lt.assertEquals('一行', 1, #proto.rows)
    lt.assertEquals('带行标题', '上', assert(proto.rows[1]).title)
    lt.assertEquals('行里的牌是视图号', support.cardId(me, first), assert(assert(proto.rows[1]).cards)[1])
    lt.assertEquals('有这张', support.cardId(me, second), assert(assert(proto.rows[1]).cards)[2])
    lt.assertEquals('没有禁用', 0, #proto.disabled)
    lt.assertEquals('没有标记', 0, #proto.marks)
end)

---@async
lt.test('面板下行：挪牌 / 禁用 / 标记攒一笔一起发增量', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local first = support.giveCard(game, me, '杀', '黑桃', 7)
    local panel = moe.panel.create(game, '测试', true, { moveable = true }):row({ first }, '上'):row({}, '下')
    moe.await.sleep(0)

    local got, undo = collect('Panel.Update', front)
    local _ <close> = undo

    panel:moveTo(first, 2, 1)
    panel:disableCard(first)
    panel:addMark(first, '${hero:张三}')
    panel:addMark(first, '第二枚')
    moe.await.sleep(0)

    lt.assertEquals('攒成一笔', 1, #got)
    local update = assert(assert(got[1]).panel)
    lt.assertEquals('带的是面板号', panel.id, update.id)
    local rows = assert(update.rows)
    lt.assertEquals('两行都变了', 2, #rows)
    lt.assertEquals('第一行空了', 0, #assert(assert(rows[1]).cards))
    lt.assertEquals('第二行拿到那张', support.cardId(me, first), assert(assert(rows[2]).cards)[1])
    lt.assertEquals('禁用带上了', support.cardId(me, first), assert(update.disabled)[1])
    local marks = assert(update.addMark)
    lt.assertEquals('两张标记就发两份', 2, #marks)
    lt.assertEquals('标记带的是那张牌', support.cardId(me, first), assert(marks[1]).card)
    lt.assertEquals('第一条标记', '${hero:张三}', assert(marks[1]).mark)
    lt.assertEquals('第二条标记', '第二枚', assert(marks[2]).mark)
end)

---@async
lt.test('面板下行：拆掉就广播 Panel.Remove', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local panel = moe.panel.create(game, '测试', true):row({ support.giveCard(game, me, '杀') })
    moe.await.sleep(0)

    local got, undo = collect('Panel.Remove', front)
    local _ <close> = undo

    local id = panel.id
    Delete(panel)
    moe.await.sleep(0)

    lt.assertEquals('一条移除', 1, #got)
    lt.assertEquals('带的是那个号', id, assert(got[1]).id)
end)
