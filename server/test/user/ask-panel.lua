local lt      = require 'test.ltest'
local support = require 'test.user.support'

--- 一局两人 + 一块两行的面板（牌从手牌里拿，好让客户端视图有号）
---@async
---@param options? Panel.Options
---@return Game
---@return Player
---@return Client
---@return Panel
local function prepare(options)
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local first  = support.giveCard(game, me, '杀', '黑桃', 7)
    local second = support.giveCard(game, me, '闪', '红桃', 2)

    local panel = moe.panel.create(game, '观星', true, options or { moveable = true, min = 0 })
        :row({ first, second }, '牌堆顶')
        :row({}, '牌堆底')
    moe.await.sleep(0)
    return game, me, front, panel
end

---@async
lt.test('询问：只报「可以操作哪块面板」，回包给选中', function ()
    local game, me, _, panel = prepare { moveable = true, min = 1, max = 1 }
    local second = assert(panel.rows[1].cards[2])

    ---@type Proto.Request.Ask.Panel?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        sent = params
        return { card = { support.cardId(me, second) } }
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('缘由原样带过去', '观星', params.reason)
    lt.assertEquals('说的是面板号', panel.id, params.id)
    lt.assertEquals('说了可以取消', true, params.cancelable)
    lt.assertEquals('也带上了时限', 10, params.timeLimit)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('选中的是它', second, ask.card)
end)

---@async
lt.test('询问：带面板号挪一张牌 ⇒ 回包说挪成了，形状由增量 Panel.Update 广播', function ()
    local game, me, front, panel = prepare()
    local first  = assert(panel.rows[1].cards[1])
    local second = assert(panel.rows[1].cards[2])

    ---@type Proto.Result.Panel.Move?
    local moved = nil
    ---@type Proto.Notify.Panel.Update?
    local updated = nil
    local _u <close> = moe.client.register('Panel.Update', function (client, params)
        if client == front then
            updated = params
        end
    end)
    local _a <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        moved = front:request('Panel.Move', {
            id   = params.id,
            card = support.cardId(me, first),
            row  = 2,
            col  = 1,
        }):await()
        moe.await.sleep(0)
        return {}
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('回包说挪成了', true, assert(moved).success)
    lt.assertEquals('面板真变了', first, panel.rows[2].cards[1])
    local update = assert(assert(updated).panel)
    lt.assertEquals('说的是这块面板', panel.id, update.id)
    local rows = assert(update.rows)
    lt.assertEquals('两行都变了', 2, #rows)
    lt.assertEquals('第一行只剩第二张', support.cardId(me, second), assert(assert(rows[1]).cards)[1])
    lt.assertEquals('第二行拿到那张', support.cardId(me, first), assert(assert(rows[2]).cards)[1])
end)

---@async
lt.test('询问：没开着询问时挪牌 ⇒ 回错误（不算故障）', function ()
    local game, me, front, panel = prepare()
    local first = assert(panel.rows[1].cards[1])

    local moved, err = front:request('Panel.Move', {
        id   = panel.id,
        card = support.cardId(me, first),
        row  = 2,
        col  = 1,
    }):await()

    lt.assertEquals('没有回包', nil, moved)
    lt.assertEquals('错在哪写在错误里', '这块面板现在没开着询问', assert(err).message)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('面板没被动过', 2, #panel.rows[1].cards)
end)

---@async
lt.test('询问：答复之后就不能再挪牌了', function ()
    local game, me, front, panel = prepare()
    local first = assert(panel.rows[1].cards[1])

    local _ <close> = moe.client.register('Ask.Panel', function ()
        return {}
    end)
    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    local late, err = front:request('Panel.Move', {
        id   = panel.id,
        card = support.cardId(me, first),
        row  = 2,
        col  = 1,
    }):await()
    lt.assertEquals('晚到的挪牌没成功', nil, late)
    lt.assertEquals('错在哪写在错误里', '这块面板现在没开着询问', assert(err).message)
    lt.assertEquals('面板没被动过', 2, #panel.rows[1].cards)
end)

---@async
lt.test('询问：挪一张号认不出的牌 ⇒ 回错误', function ()
    local game, me, front, panel = prepare()

    ---@type Proto.Result.Panel.Move?
    local moved = nil
    ---@type Proto.Error?
    local err = nil
    local _ <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        moved, err = front:request('Panel.Move', {
            id   = params.id,
            card = 999999,
            row  = 1,
            col  = 1,
        }):await()
        return {}
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('没有回包', nil, moved)
    lt.assertEquals('错在哪写在错误里', '认不出这张牌', assert(err).message)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_PARAMS, assert(err).code)
    lt.assertEquals('面板没被动过', 2, #panel.rows[1].cards)
end)

---@async
lt.test('询问：挪别人面板上的牌 ⇒ 回错误', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(fronts[2])

    local first = support.giveCard(game, me, '杀', '黑桃', 7)
    local panel = moe.panel.create(game, '观星', true, { moveable = true, min = 0 })
        :row({ first }, '牌堆顶')
    moe.await.sleep(0)

    ---@type Proto.Result.Panel.Move?
    local moved = nil
    ---@type Proto.Error?
    local err = nil
    local _ <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        moved, err = other:request('Panel.Move', {
            id   = params.id,
            card = support.cardId(me, first),
            row  = 1,
            col  = 1,
        }):await()
        return {}
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('没有回包', nil, moved)
    lt.assertEquals('错在哪写在错误里', '这块面板不是问他的', assert(err).message)
    lt.assertEquals('面板没被动过', 1, #panel.rows[1].cards)
end)

---@async
lt.test('询问：挪一张不合法的牌 ⇒ 回包说没挪成，面板不动', function ()
    local game, me, front, panel = prepare()
    local first = assert(panel.rows[1].cards[1])

    ---@type Proto.Result.Panel.Move?
    local moved = nil
    local _ <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        moved = front:request('Panel.Move', {
            id   = params.id,
            card = support.cardId(me, first),
            row  = 9,
            col  = 1,
        }):await()
        return {}
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('回包说没挪成', false, assert(moved).success)
    lt.assertEquals('面板没动', first, panel.rows[1].cards[1])
end)

---@async
lt.test('询问：挪牌的行号不是数字 ⇒ 回「参数不对」（进不了内核）', function ()
    local game, me, front, panel = prepare()
    local first = assert(panel.rows[1].cards[1])

    ---@type Proto.Error?
    local err = nil
    local _ <close> = moe.client.register('Ask.Panel', function (_, params)
        ---@cast params Proto.Request.Ask.Panel
        local _, why = front:request('Panel.Move', {
            id   = params.id,
            card = support.cardId(me, first),
            row  = '甲',
            col  = 1,
        }):await()
        err = why
        return {}
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('错误码说清是参数问题', moe.jsonrpc.INVALID_PARAMS, assert(err).code)
    lt.assertEquals('错在哪说清楚', '「row」应该是 integer（现在是 string）', assert(err).message)
    lt.assertEquals('面板没被动过', 2, #panel.rows[1].cards)
end)

---@async
lt.test('询问：答复一次就收（协议上答复 = 操作完了）', function ()
    local game, me, _, panel = prepare { moveable = false, min = 1, max = 1 }
    local first = assert(panel.rows[1].cards[1])

    local rounds = 0
    local _ <close> = moe.client.register('Ask.Panel', function ()
        rounds = rounds + 1
        return { card = { support.cardId(me, first) } }
    end)

    local ask = moe.askPanel.create { game = game, to = me, reason = '观星', panel = panel }
    ask:apply():await()

    lt.assertEquals('只问了一次', 1, rounds)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('选中的是第一张', first, ask.card)
end)
