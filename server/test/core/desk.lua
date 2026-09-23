local lt = require 'test.ltest'

---@return Player
local function newPlayer()
    local system = moe.attribute.create()
    return moe.player.create { attributes = system:createInstance() }
end

lt.test('桌子：座位号决定行动顺序', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    local c    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)
    desk:sit(3, c)

    lt.assertEquals('1 号位的下一个是 2 号位', b, desk:getNext(a))
    lt.assertEquals('再下一个是 3 号位', c, desk:getNext(b))
    lt.assertEquals('3 号位之后回到 1 号位', a, desk:getNext(c))
    lt.assertEquals('座位列表按座位号升序', 3, #desk.players)
    lt.assertEquals('第一个是 1 号位', a, desk.players[1])
    lt.assertEquals('1 号位上的玩家查得到', a, desk:getPlayer(1))
    lt.assertEquals('玩家能查出自己的座位号', 2, desk:getIndex(b))
end)

lt.test('桌子：按行动顺序依次给出角色，轮到自己就结束', function ()
    local desk = moe.desk.create(5)
    local a    = newPlayer()
    local b    = newPlayer()
    local c    = newPlayer()
    local d    = newPlayer()
    local e    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)
    desk:sit(3, c)
    desk:sit(4, d)
    desk:sit(5, e)

    ---@param allowed Player[]?
    ---@param from Player?
    ---@return string # 座位号连起来
    local function seats(allowed, from)
        ---@type string[]
        local list = {}
        for player in desk:actionOrder(allowed, from) do
            list[#list + 1] = tostring(desk:getIndex(player))
        end
        return table.concat(list, ',')
    end

    lt.assertEquals('允许列表里没有自己 ⇒ 从下家开始绕一圈', '3,4,5,1', seats({ e, c, a, d }, b))
    lt.assertEquals('自己在允许列表里 ⇒ 排在最前', '2,3,4,5,1', seats({ b, c, d, e, a }, b))
    lt.assertEquals('不给允许列表表示都允许', '2,3,4,5,1', seats(nil, b))
    lt.assertEquals('只允许自己 ⇒ 就自己一个', '1', seats({ a }, a))
    lt.assertEquals('允许列表里重复的角色只给一次', '2', seats({ b, b }, a))
    lt.assertEquals('允许列表外的角色跳过', '3,4', seats({ c, d }, b))
    lt.assertEquals('允许列表里的桌外角色跳过', '2,3,4,5', seats({ newPlayer(), b, c, d, e }, a))
    lt.assertError('起点不在桌上报错', function ()
        desk:actionOrder(nil, newPlayer())
    end)
end)

lt.test('桌子：不给起点就用当前回合角色', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    local c    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)
    desk:sit(3, c)

    local game = moe.game.create { desk = desk, random = moe.random.create(1) }
    game.turnPlayer = b

    ---@type string[]
    local list = {}
    for player in desk:actionOrder() do
        list[#list + 1] = tostring(desk:getIndex(player))
    end
    lt.assertEquals('从当前回合角色起绕一圈', '2,3,1', table.concat(list, ','))

    game.turnPlayer = nil
    lt.assertError('既不在回合里、又没给起点 ⇒ 报错', function ()
        desk:actionOrder()
    end)
end)

lt.test('桌子：同一名角色占两个座位也只给一次', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)
    desk:sit(3, a)

    ---@type string[]
    local list = {}
for player in desk:actionOrder(nil, b) do
        list[#list + 1] = tostring(desk:getIndex(player))
    end
    lt.assertEquals('同一个角色只给一次', '2,1', table.concat(list, ','))
end)

lt.test('桌子：跳过不参与行动的玩家', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    local c    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)
    desk:sit(3, c)

    b:setAlive(false)
    lt.assertEquals('跳过不参与行动的玩家', c, desk:getNext(a))

    b:setAlive(true)
    lt.assertEquals('复活后又排进来', b, desk:getNext(a))
end)

lt.test('桌子：跳过空座位', function ()
    local desk = moe.desk.create(5)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)
    desk:sit(4, b)

    lt.assertEquals('从 1 号位直接跳到 4 号位', b, desk:getNext(a))
    lt.assertEquals('从 4 号位绕回 1 号位', a, desk:getNext(b))
    lt.assertEquals('座位列表只有两个玩家', 2, #desk.players)
end)

lt.test('桌子：座位列表跟着入座更新', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()

    desk:sit(1, a)
    lt.assertEquals('先读一次（建立缓存）', 1, #desk.players)

    local b = newPlayer()
    desk:sit(3, b)
    lt.assertEquals('新入座的也进列表', 2, #desk.players)
    lt.assertEquals('按座位号排序', b, desk.players[2])
end)

lt.test('桌子：存活列表跟着死亡更新', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)

    local game = moe.game.create { desk = desk, random = moe.random.create(1) }

    lt.assertEquals('先读一次（建立缓存），两个都在', 2, #desk.alivePlayers)

    a:setAlive(false)

    lt.assertEquals('死掉的移出列表', 1, #desk.alivePlayers)
    lt.assertEquals('留下的是活着的那个', b, desk.alivePlayers[1])
    lt.assertEquals('座位列表不受影响', 2, #desk.players)
    lt.assertEquals('局照旧带着这张桌子', desk, game.desk)
end)

lt.test('桌子：先有局再入座，玩家也拿得到局', function ()
    local desk = moe.desk.create(2)
    local game = moe.game.create { desk = desk, random = moe.random.create(1) }
    local a    = newPlayer()
    desk:sit(1, a)

    ---@type Player?
    local seen = nil
    game:on('玩家-死亡', function (ctx)
        seen = ctx
    end)

    a:setAlive(false)

    lt.assertEquals('入座时回填了局，死亡时机发得出来', a, seen)
end)

lt.test('桌子：同一座位与相邻座位距离都是 1', function ()
    local desk = moe.desk.create(8)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)
    desk:sit(2, b)

    lt.assertEquals('相邻座位是 1', 1, desk:getDistance(a, b))
    lt.assertEquals('自己到自己也是 1', 1, desk:getDistance(a, a))
end)

lt.test('桌子：沿较短方向计算距离', function ()
    local desk = moe.desk.create(8)
    local a    = newPlayer()
    local b    = newPlayer()
    local c    = newPlayer()
    desk:sit(1, a)
    desk:sit(5, b)
    desk:sit(8, c)

    lt.assertEquals('8 座桌上 1 号到 5 号是 4', 4, desk:getDistance(a, b))
    lt.assertEquals('8 座桌上 1 号到 8 号是 1（另一个方向）', 1, desk:getDistance(a, c))
    lt.assertEquals('距离与方向对称', 4, desk:getDistance(b, a))
end)

lt.test('桌子：距离按座位总数求值', function ()
    local wide   = moe.desk.create(8)
    local narrow = moe.desk.create(5)
    local a      = newPlayer()
    local b      = newPlayer()
    wide:sit(1, a)
    wide:sit(5, b)
    narrow:sit(1, a)
    narrow:sit(5, b)

    lt.assertEquals('8 座桌上是 4', 4, wide:getDistance(a, b))
    lt.assertEquals('5 座桌上是 1', 1, narrow:getDistance(a, b))
end)

lt.test('桌子：非法入座报错', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)

    lt.assertError('同一个座位不能坐两个人', function ()
        desk:sit(1, b)
    end)
    lt.assertError('座位号越界报错', function ()
        desk:sit(4, b)
    end)
    lt.assertError('座位号不是整数报错', function ()
        desk:sit(1.5, b)
    end)
end)

lt.test('桌子：不在桌上的玩家不能参与求值', function ()
    local desk = moe.desk.create(3)
    local a    = newPlayer()
    local b    = newPlayer()
    desk:sit(1, a)

    lt.assertError('没入座的玩家没有下一个行动者', function ()
        desk:getNext(b)
    end)
    lt.assertError('没入座的玩家不参与距离求值', function ()
        desk:getDistance(a, b)
    end)
end)
