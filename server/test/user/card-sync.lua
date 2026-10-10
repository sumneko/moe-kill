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

--- 两个客户端都接入（建账 + 收下行）
---@param players Player[]
local function attach(players)
    for _, player in ipairs(players) do
        assert(player.user):attach()
    end
end

--- 搭一个两人局：每人坐好、都有连接，同步层已经盯上（每条用例一次，顺带撤掉上一轮的收集器）
---@param seed? integer # 随机种子（要重复抽样时换个种子，不然每轮抽到同一个结果）
---@return Game
---@return Player[]
local function newGame(seed)
    reset()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(seed or 1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        game.desk:sit(i, player)
        local _, back = connect()
        player:setUser(New 'ClientUser' (game, back))
        players[i] = player
    end
    players[1]:getZone('手牌'):setVisible { players[1] }
    players[2]:getZone('手牌'):setVisible { players[2] }
    return game, players
end

---@async
lt.test('卡牌同步：建视图时把当时场上的牌都算进账', function ()
    local game = newGame()
    game:getZone('弃牌'):accept(game:createCard('闪'))

    local me = assert(game.desk.players[1])
    local user = assert(me.user)
    local cards = assert(user.cardView).snapshot

    lt.assertEquals('场上那张在快照里', 1, #cards)
    lt.assertEquals('带着牌面', '闪', assert(cards[1].face).name)
    lt.assertEquals('区域是弃牌', '弃牌', assert(cards[1].zone).name)
    lt.assertEquals('没有主人', nil, assert(cards[1].zone).player)
end)

---@async
lt.test('卡牌同步：看不见的牌只有号与区域', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local you = assert(players[2])
    attach(players)
    local got = collect('Card.Create')

    you:getZone('手牌'):accept(game:createCard('杀'))
    moe.await.sleep(0)

    local mine  = assert(got[1]).cards
    local yours = assert(got[2]).cards
    lt.assertEquals('看不见别人的手牌', nil, assert(mine[1]).face)
    lt.assertEquals('但那张牌的存在看得见', 1, #mine)
    lt.assertEquals('号是给了的（后续搬动要认它）', true, mine[1].id ~= nil)
    lt.assertEquals('区域主人的号对得上', you.id, mine[1].zone.player)
    lt.assertEquals('区名是手牌', '手牌', mine[1].zone.name)
    lt.assertEquals('他自己那份看得见牌面', '杀', assert(assert(yours[1]).face).name)
end)

---@async
lt.test('卡牌同步：自己的手牌看得见', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
    local got = collect('Card.Create')

    me:getZone('手牌'):accept(game:createCard('桃'))
    moe.await.sleep(0)

    lt.assertEquals('自己那张带牌面', '桃', assert(assert(got[1]).cards[1].face).name)
    lt.assertEquals('对方那份没有牌面', nil, assert(assert(got[2]).cards[1]).face)
end)

---@async
lt.test('卡牌同步：牌进区发创建、离区发移除', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
    local creates = collect('Card.Create')
    local removes = collect('Card.Remove')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)

    lt.assertEquals('两个连接各一条创建', 2, #creates)
    lt.assertEquals('第一条里有一张牌', 1, #assert(creates[1]).cards)
    lt.assertEquals('是那张牌', '杀', creates[1].cards[1].face.name)
    local id = creates[1].cards[1].id

    game:moveCard(card, '弃牌')
    moe.await.sleep(0)

    lt.assertEquals('两个连接各一条移除', 2, #removes)
    lt.assertEquals('移除的是旧 id', id, assert(removes[1]).ids[1])
end)

---@async
lt.test('卡牌同步：暗区里进新牌，号会被洗一遍', function ()
    -- 洗号用的是视图自带的随机源（不碰局里的）—— 用例把种子固定下来逐轮盯着看（洗了也可能恰好不动）
    local swapped = 0
    for seed = 1, 8 do
        local game, players = newGame(seed)
        local you = assert(players[2])
        attach(players)
        local got = collect('Card.Create')

        local first = game:createCard('杀')
        you:getZone('手牌'):accept(first)
        moe.await.sleep(0)

        local view = assert(assert(players[1].user).cardView)
        local idFirst = assert(view.cardMap[first]).id

        clear(got)
        view.random = moe.random.create(seed)
        local second = game:createCard('杀')
        you:getZone('手牌'):accept(second)
        moe.await.sleep(0)

        local idSent     = assert(assert(got[1]).cards[1]).id
        local idFirstNow  = assert(view.cardMap[first]).id
        local idSecondNow = assert(view.cardMap[second]).id
        lt.assertEquals('两张牌各占一个号', true, idFirstNow ~= idSecondNow)
        lt.assertEquals('客户端拿到的号就是账里发出去的那个', idSecondNow, idSent)
        lt.assertEquals('换号只在对调：原先那个号还在（只是换了主人）', true,
            idFirstNow == idFirst or idSecondNow == idFirst)
        if idFirstNow ~= idFirst then
            swapped = swapped + 1
        end
    end
    lt.assertEquals('有时候会把先来那张的号换走（说明换过号）', true, swapped > 0)
end)

---@async
lt.test('卡牌同步：一批暗牌进区，号不重不漏、都不带面', function ()
    local game, players = newGame()
    local me = assert(players[1])
    game:getZone('抽牌'):setVisible(false)
    attach(players)

    local deck = game:getZone('抽牌')
    ---@type Card[]
    local batch = {}
    for i = 1, 20 do
        batch[i] = game:createCard('杀')
    end
    game:moveCard(batch, deck)
    moe.await.sleep(0)

    local view = assert(assert(me.user).cardView)
    ---@type table<integer, true>
    local seen  = {}
    local count = 0
    for _, list in pairs(view.cardZones) do
        for _, card in ipairs(list) do
            local pcard = assert(view.cardMap[card])
            count = count + 1
            lt.assertEquals('暗牌不带面', nil, pcard.face)
            lt.assertEquals('号没重复', nil, seen[pcard.id])
            seen[pcard.id] = true
        end
    end
    lt.assertEquals('20 张牌、20 个号', 20, count)
end)

---@async
lt.test('卡牌同步：换区会换新 id（移除 + 创建）', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
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
    attach(players)
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
    lt.assertEquals('牌自己那份面不动', '杀', updates[1].cards[1].face.name)
    lt.assertEquals('转化另发一份', '火杀', updates[1].cards[1].modifier.name)
end)

---@async
lt.test('卡牌同步：没转化就不带 modifier', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
    local creates = collect('Card.Create')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)

    local sent = assert(creates[1]).cards[1]
    lt.assertEquals('牌自己那份面照发', '杀', sent.face.name)
    lt.assertEquals('没转化就不带 modifier', nil, sent.modifier)
end)

---@async
lt.test('卡牌同步：加了转化又撤销，等于没变，不发通知', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
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
    attach(players)
    local creates = collect('Card.Create')
    local moves = collect('Card.Move')

    local card = game:createCard('杀')
    me:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    local id = assert(creates[1]).cards[1].id
    clear(moves)

    game:moveCard(card, '弃牌')

    lt.assertEquals('当场就发了（不用等调度），两个连接各一条', 2, #moves)
    local sent = assert(moves[1]).moves[1]
    lt.assertEquals('带的是搬之前的 id', id, sent.id)
    lt.assertEquals('来源是对的手牌', '手牌', sent.from.name)
    lt.assertEquals('来源主人对得上', me.id, sent.from.player)
    lt.assertEquals('目标是弃牌堆', '弃牌', sent.to.name)
end)

---@async
lt.test('卡牌同步：看不见的牌搬动时给号、不给牌面', function ()
    local game, players = newGame()
    local you = assert(players[2])
    attach(players)
    local moves = collect('Card.Move')

    local card = game:createCard('杀')
    you:getZone('手牌'):accept(card)
    moe.await.sleep(0)
    clear(moves)

    game:moveCard(card, '弃牌')

    local mine = assert(moves[1]).moves[1]
    lt.assertEquals('号给了（客户端靠它认账里那张）', true, mine.id ~= nil)
    lt.assertEquals('牌面不给（本来是背面）', nil, mine.face)
    local yours = assert(moves[2]).moves[1]
    lt.assertEquals('他自己看得见，自带牌面', '杀', assert(yours.face).name)
end)

---@async
lt.test('卡牌同步：无名区（临时区）之间互移不发移动、也不换 id', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
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
    local view = assert(assert(me.user).cardView)
    lt.assertEquals('视图里那张牌的 id 没变', id, assert(view.cardMap[card]).id)
end)

---@async
lt.test('卡牌同步：一笔调度里连改两次只发一次', function ()
    local game, players = newGame()
    local me = assert(players[1])
    attach(players)
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
    lt.assertEquals('牌自己那份面不动', '杀', updates[1].cards[1].face.name)
end)

---@async
lt.test('卡牌同步：一批牌一起挪进暗区，账里的区域要跟得上', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local you = assert(players[2])
    attach(players)

    local deck = game:getZone('抽牌')
    deck:setVisible(false)
    ---@type Card[]
    local cards = {}
    for i = 1, 5 do
        cards[i] = game:createCard('杀')
    end
    deck:accept(cards)
    moe.await.sleep(0)

    game:moveCard(cards, you:getZone('手牌'))
    moe.await.sleep(0)

    local view = assert(assert(me.user).cardView)
    local count = 0
    local stale = 0
    for _ in pairs(view.cardMap) do
        count = count + 1
    end
    for _, snapshot in pairs(view.cardMap) do
        if assert(snapshot.zone).name == '抽牌' then
            stale = stale + 1
        end
    end
    lt.assertEquals('五个号都在账上', 5, count)
    lt.assertEquals('没有还挂在抽牌堆的号', 0, stale)
    for i = 1, #cards do
        local snapshot = assert(view.cardMap[cards[i]])
        lt.assertEquals('账里的区域是手牌', '手牌', assert(snapshot.zone).name)
        lt.assertEquals('区域主人是对方', you.id, snapshot.zone.player)
    end
end)

---@async
lt.test('卡牌同步：换号不消耗局里的随机源', function ()
    local gameA = newGame(7)
    ---@type integer[]
    local numsA = {}
    for i = 1, 6 do
        numsA[i] = gameA.random:nextInt(1, 1000000)
    end

    local gameB, players = newGame(7)
    local you = assert(players[2])
    attach(players)
    local first = gameB:createCard('杀')
    you:getZone('手牌'):accept(first)
    moe.await.sleep(0)
    local second = gameB:createCard('杀')
    you:getZone('手牌'):accept(second)
    moe.await.sleep(0)

    ---@type integer[]
    local numsB = {}
    for i = 1, 6 do
        numsB[i] = gameB.random:nextInt(1, 1000000)
    end
    lt.assertEquals('两边序列一致（换号没动局里的随机源）', table.concat(numsA, ','), table.concat(numsB, ','))
end)

lt.test('卡牌同步：视图挂在 ClientUser 上（懒建、同一份、知道主人、建账就在）', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local user = assert(me.user)
    game:getZone('弃牌'):accept(game:createCard('闪'))

    lt.assertEquals('第一次读就懒建出来', true, user.cardView ~= nil)
    local view = assert(user.cardView)
    lt.assertEquals('再读还是同一份', true, user.cardView == view)
    lt.assertEquals('知道自己是哪个人的', user, view.user)
    lt.assertEquals('连同当时的牌一起建账', 1, #view.snapshot)
end)
