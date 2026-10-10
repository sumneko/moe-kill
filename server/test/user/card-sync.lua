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
lt.test('卡牌同步：看不见的新牌会与同区一张匿名牌换号', function ()
    -- 换号挑牌用的是视图自带的随机源（不碰局里的）—— 用例把种子固定下来逐轮盯着看（也可能抽到自己 = 不换）
    local swapped = 0
    for seed = 1, 8 do
        local game, players = newGame(seed)
        local you = assert(players[2])
        local got = collect('Card.Create')

        local first = game:createCard('杀')
        you:getZone('手牌'):accept(first)
        moe.await.sleep(0)

        local user = assert(players[1].user)
        local view = assert(user.cardView)
        local idFirst = assert(view.cards[first]).id

        clear(got)
        view.random = moe.random.create(seed)
        local second = game:createCard('杀')
        you:getZone('手牌'):accept(second)
        moe.await.sleep(0)

        local idSent = assert(assert(got[1]).cards[1]).id
        lt.assertEquals('发出去的是个没用过的号', true, idSent ~= idFirst)
        local idFirstNow  = assert(view.cards[first]).id
        local idSecondNow = assert(view.cards[second]).id
        lt.assertEquals('两张牌占的还是那两个号', true,
            (idFirstNow == idFirst and idSecondNow == idSent)
            or (idFirstNow == idSent and idSecondNow == idFirst))
        if idFirstNow ~= idFirst then
            swapped = swapped + 1
        end
    end
    lt.assertEquals('有时候会把先来那张的号换走（说明换过号）', true, swapped > 0)
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
    local view = user.cardView
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

---@async
lt.test('卡牌同步：一批牌一起挪进暗区，账里的区域要跟得上（不与没结算的脏牌换号）', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local you = assert(players[2])

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

    local user = assert(me.user)
    local view = assert(user.cardView)
    local count = 0
    local stale = 0
    for _, snapshot in pairs(view.cards) do
        count = count + 1
        if snapshot.zone.name == '抽牌' then
            stale = stale + 1
        end
    end
    lt.assertEquals('五个号都在账上', 5, count)
    lt.assertEquals('没有还挂在抽牌堆的号', 0, stale)
    for i = 1, #cards do
        local snapshot = assert(view.cards[cards[i]])
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

---@async
lt.test('卡牌同步：全量重发可以只给一个玩家，旧账的号先撤掉', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local creates = collect('Card.Create')
    local removes = collect('Card.Remove')

    local card = game:createCard('闪')
    game:getZone('弃牌'):accept(card)
    moe.cardSync.syncAll(game)
    moe.await.sleep(0)

    lt.assertEquals('开局两台各灌一份', 2, #creates)
    local idFirst = assert(assert(creates[1]).cards[1]).id
    clear(creates)
    clear(removes)

    moe.cardSync.syncAll(game, me)
    moe.await.sleep(0)

    lt.assertEquals('只有指定玩家收到重灌', 1, #creates)
    lt.assertEquals('旧账的号先撤掉了', 1, #removes)
    lt.assertEquals('撤的就是他账上那个号', idFirst, assert(removes[1]).ids[1])
    local fresh = assert(assert(creates[1]).cards[1])
    lt.assertEquals('新发的号没用过', true, fresh.id ~= idFirst)
    lt.assertEquals('新那份还带着牌面', '闪', assert(fresh.template).name)
end)

---@async
lt.test('卡牌同步：全量重发不丢掉「最近一次搬动」的可见性', function ()
    local game, players = newGame()
    local me = assert(players[1])
    local got = collect('Card.Create')

    local card = game:createCard('闪')
    game:getZone('弃牌'):accept(card, { me })
    moe.await.sleep(0)
    lt.assertEquals('我看得见牌面', '闪', assert(assert(got[1]).cards[1]).template.name)
    lt.assertEquals('对方看不见（那次搬动只对我可见）', nil, assert(assert(got[2]).cards[1]).template)

    clear(got)
    moe.cardSync.syncAll(game)
    moe.await.sleep(0)

    lt.assertEquals('重灌后我照旧看得见', '闪', assert(assert(got[1]).cards[1]).template.name)
    lt.assertEquals('重灌后对方照旧看不见', nil, assert(assert(got[2]).cards[1]).template)
end)

lt.test('卡牌同步：视图挂在 ClientUser 上（懒建、同一份、知道主人）', function ()
    local _, players = newGame()
    local me = assert(players[1])
    local user = assert(me.user)

    lt.assertEquals('第一次读就懒建出来', true, user.cardView ~= nil)
    local view = assert(user.cardView)
    lt.assertEquals('再读还是同一份', true, user.cardView == view)
    lt.assertEquals('知道自己是哪个座位的', me, view.player)
end)
