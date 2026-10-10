local lt = require 'test.ltest'

--- 本用例文件用过、还没撤的收集器（每条用例开头统一撤掉，任何一条失败都不会连锁）
---@type fun()[]
local pending = {}

--- 清空一个收件箱（handler 闭包握着原表，所以就地清）
---@param list any[]
local function clear(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

--- 收某一类消息（两个连接各收一份，所以条数通常是 2 的倍数）
---@param method string
---@return any[]
local function collect(method)
    local got = {}
    local undo = moe.client.register(method, function (_, params)
        got[#got + 1] = params
    end)
    pending[#pending + 1] = undo
    return got
end

--- 把上一轮用过的收集器全撤掉
local function reset()
    for i = #pending, 1, -1 do
        local undo = assert(pending[i])
        pending[i] = nil
        undo()
    end
end

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
local function connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 搭一个两人局：每人坐好、都有连接，同步层已经盯上（每条用例一次，顺带撤掉上一轮的收集器）
---@return Game
---@return Player[]
local function newGame()
    reset()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        game.desk:sit(i, player)
        local _, back = connect()
        player:setUser(New 'ClientUser' (back))
        players[i] = player
    end
    players[1]:getZone('手牌'):setVisible { players[1] }
    players[2]:getZone('手牌'):setVisible { players[2] }
    moe.cardSync.watch(game)
    return game, players
end

---@async
lt.test('卡牌同步：全量灌入把各区的牌都发一遍', function ()
    local game = newGame()
    local got = collect('Card.Create')
    game:getZone('弃牌'):accept(game:createCard('闪'))

    moe.cardSync.syncAll(game)
    moe.await.sleep(0)

    lt.assertEquals('两个连接各一条', 2, #got)
    lt.assertEquals('弃牌堆那张在里面', 1, #got[1].cards)
    lt.assertEquals('牌面带上了', '闪', got[1].cards[1].template.name)
    lt.assertEquals('区域是弃牌', '弃牌', got[1].cards[1].zone.name)
    lt.assertEquals('没有主人', nil, got[1].cards[1].zone.player)
end)

---@async
lt.test('卡牌同步：看不见的牌只有 id 与区域', function ()
    local game, players = newGame()
    local you = assert(players[2])
    local got = collect('Card.Create')

    you:getZone('手牌'):accept(game:createCard('杀'))
    moe.cardSync.syncAll(game)
    moe.await.sleep(0)

    local mine  = assert(got[1]).cards
    local yours = assert(got[2]).cards
    lt.assertEquals('看不见别人的手牌', nil, assert(mine[1]).template)
    lt.assertEquals('但那张牌的存在看得见', 1, #mine)
    lt.assertEquals('区域主人的号对得上', you.id, mine[1].zone.player)
    lt.assertEquals('区名是手牌', '手牌', mine[1].zone.name)
    lt.assertEquals('他自己那份看得见牌面', '杀', assert(assert(yours[1]).template).name)
end)

---@async
lt.test('卡牌同步：自己的手牌看得见', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local got = collect('Card.Create')

    me:getZone('手牌'):accept(game:createCard('桃'))
    moe.cardSync.syncAll(game)
    moe.await.sleep(0)

    lt.assertEquals('自己那张带牌面', '桃', assert(assert(got[1]).cards[1]).template.name)
    lt.assertEquals('对方那份没有牌面', nil, assert(assert(got[2]).cards[1]).template)
end)

---@async
lt.test('卡牌同步：牌进区发创建、离区发移除', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local removes = collect('Card.Remove')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)

    lt.assertEquals('两个连接各一条创建', 2, #creates)
    lt.assertEquals('第一条里有一张牌', 1, #assert(creates[1]).cards)
    lt.assertEquals('是那张牌', '杀', creates[1].cards[1].template.name)
    local id = creates[1].cards[1].id

    game:moveCard(card, '弃牌')
    moe.await.sleep(0)

    lt.assertEquals('两个连接各一条移除', 2, #removes)
    lt.assertEquals('移除的是旧 id', id, assert(removes[1]).ids[1])
end)

---@async
lt.test('卡牌同步：看不见的区里移除一张，报出去的 id 不是它自己那个', function ()
    -- 打乱本身是随机的 ⇒ 单次可能恰好还落在原 id 上，所以跑若干轮统计
    local sameCount = 0
    for round = 1, 6 do
        local game, players = newGame()
        local you = assert(players[2])
        local creates = collect('Card.Create')
        local removes = collect('Card.Remove')

        ---@type Card[]
        local hand = {}
        for i = 1, 8 do
            hand[i] = game:createCard('杀')
            you:getZone('手牌'):accept(hand[i])
        end
        moe.await.sleep(0)
        clear(creates)
        clear(removes)

        local user = assert(players[1].user)
        ---@cast user ClientUser
        local view = moe.cardSync.views[user.client]
        local mine = assert(view).cards
        ---@type table<integer, Card>
        local byId = {}
        for _, card in ipairs(hand) do
            local snapshot = assert(mine[card])
            byId[snapshot.id] = card
        end

        local target   = assert(hand[1])
        local idBefore = assert(mine[target]).id

        game:moveCard(target, '弃牌')
        moe.await.sleep(0)

        lt.assertEquals('两个连接各一条移除', 2, #removes)
        local removed = assert(removes[1]).ids[1]
        lt.assertEquals('移除的必须是他手牌里的匿名 id 之一', true, byId[removed] ~= nil)
        lt.assertEquals('弃牌堆那张照样看得见牌面', '杀', assert(creates[1]).cards[1].template.name)
        if removed == idBefore then
            sameCount = sameCount + 1
        end
    end
    lt.assertEquals('不会每一轮都报「那张自己的 id」（说明打乱过）', true, sameCount < 6)
end)

---@async
lt.test('卡牌同步：换区会换新 id（移除 + 创建）', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local removes = collect('Card.Remove')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    local before = assert(creates[1]).cards[1].id
    clear(creates)

    game:moveCard(card, '弃牌')
    moe.await.sleep(0)

    lt.assertEquals('旧 id 被移除', before, assert(removes[1]).ids[1])
    local after = assert(creates[1]).cards[1].id
    lt.assertEquals('新 id 不一样', true, after ~= before)
    lt.assertEquals('新那份在弃牌堆', '弃牌', creates[1].cards[1].zone.name)
end)

---@async
lt.test('卡牌同步：区域没变就原地更新（id 不变）', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local updates = collect('Card.Update')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    local id = assert(creates[1]).cards[1].id

    card:addModifier { name = '火杀' }
    moe.await.sleep(0)

    lt.assertEquals('没有多出创建', 2, #creates)
    lt.assertEquals('只有看得见的那个连接收到更新（另一个没变化）', 1, #updates)
    lt.assertEquals('id 没变', id, assert(updates[1]).cards[1].id)
    lt.assertEquals('牌自己那份面不动', '杀', updates[1].cards[1].template.name)
    lt.assertEquals('转化另发一份', '火杀', updates[1].cards[1].modifier.name)
end)

---@async
lt.test('卡牌同步：没转化就不带 modifier', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)

    local sent = assert(creates[1]).cards[1]
    lt.assertEquals('牌自己那份面照发', '杀', sent.template.name)
    lt.assertEquals('没转化就不带 modifier', nil, sent.modifier)
end)

---@async
lt.test('卡牌同步：加了转化又撤销，等于没变，不发通知', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local updates = collect('Card.Update')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    clear(creates)

    local undoModifier = card:addModifier { name = '火杀' }
    undoModifier()
    moe.await.sleep(0)

    lt.assertEquals('没有新创建', 0, #creates)
    lt.assertEquals('没有原地更新', 0, #updates)
end)

---@async
lt.test('卡牌同步：搬牌当场发移动通知', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local moves = collect('Card.Move')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    local id = assert(creates[1]).cards[1].id
    clear(moves)

    game:moveCard(card, '弃牌')

    lt.assertEquals('当场就发了（不用等调度），两个连接各一条', 2, #moves)
    lt.assertEquals('带的是搬之前的 id', id, assert(moves[1]).cards[1].id)
    lt.assertEquals('来源是对的手牌', '手牌', moves[1].from.name)
    lt.assertEquals('来源主人对得上', me.id, moves[1].from.player)
    lt.assertEquals('目标是弃牌堆', '弃牌', moves[1].to.name)
end)

---@async
lt.test('卡牌同步：无名区（临时区）之间互移不发移动、也不换 id', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local removes = collect('Card.Remove')
    local moves   = collect('Card.Move')

    local card   = game:createCard('杀')
    local first  = moe.zone.create(game)
    local second = moe.zone.create(game)
    first:accept(card)
    moe.await.sleep(0)
    local id = assert(creates[1]).cards[1].id
    clear(creates)
    clear(moves)

    second:accept(card)
    moe.await.sleep(0)

    lt.assertEquals('不发移动通知', 0, #moves)
    lt.assertEquals('不发移除', 0, #removes)
    lt.assertEquals('也没有新创建', 0, #creates)
    local user = assert(me.user)
    ---@cast user ClientUser
    local view = moe.cardSync.views[user.client]
    lt.assertEquals('视图里那张牌的 id 没变', id, assert(view).cards[card].id)
end)

---@async
lt.test('卡牌同步：一笔调度里连改两次只发一次', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local updates = collect('Card.Update')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    clear(updates)

    card:addModifier { name = '火杀' }
    card:addModifier { suit = '红桃' }
    moe.await.sleep(0)

    lt.assertEquals('一条创建（每个连接）', 1, #creates / 2)
    lt.assertEquals('两次改动合成一条更新', 1, #updates)
    lt.assertEquals('两次改动都在同一条里', '红桃', updates[1].cards[1].modifier.suit)
    lt.assertEquals('转化那份带着牌名', '火杀', updates[1].cards[1].modifier.name)
    lt.assertEquals('牌自己那份面不动', '杀', updates[1].cards[1].template.name)
end)
