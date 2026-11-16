local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('判定下行：判了成败就广播一条 Judge.Result（带判定牌牌面）', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    ---@type Proto.Notify.Judge.Result[]
    local got = {}
    local _ <close> = moe.client.register('Judge.Result', function (client, params)
        if client == front then
            got[#got + 1] = params
        end
    end)

    -- 这局还没走开局，抽牌堆是空的：自己放一张进去当判定牌
    local deck = assert(game:getZone('抽牌'), '没有抽牌')
    deck:accept(game:createCard('杀', '黑桃', 7))

    local judge = game:judge(me, '八卦阵', function ()
        return true
    end)
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    local data = assert(got[1])
    lt.assertEquals('判定者', me.id, data.player)
    lt.assertEquals('缘由带着', '八卦阵', data.reason)
    lt.assertEquals('判定牌就是翻出来的那张', assert(judge.card).name, assert(data.face).name)
    lt.assertEquals('成败', true, data.passed)
end)

---@async
lt.test('判定下行：没判过成败就不发', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local count = 0
    local _ <close> = moe.client.register('Judge.Result', function (client)
        if client == front then
            count = count + 1
        end
    end)

    local deck = assert(game:getZone('抽牌'), '没有抽牌')
    deck:accept(game:createCard('杀', '黑桃', 7))

    game:judge(me, '测试')
    moe.await.sleep(0)

    lt.assertEquals('一次都没发', 0, count)
end)
