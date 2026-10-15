local lt      = require 'test.ltest'
local support = require 'test.user.support'

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

--- 搭一个两人局：每人坐好、都接了客户端并接入下行（外壳那步由用例代劳）
---@return Game
---@return Player[]
---@return Client[] # 前端侧（用例拿它发请求）
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    ---@type Client[]
    local fronts = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local front, back = connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
        fronts[i]  = front
    end
    moe.snapshot.attach(game)
    return game, players, fronts
end

---@async
lt.test('快照：技能与面板也一次带上（重连够用）', function ()
    local game, players, fronts = support.newPackageGame()
    local me = assert(players[1])
    me:setHero(assert(game:getHero('刘备')))
    local panel = moe.panel.create(game, '测面板')
    panel:row({}, '第一行')
    moe.await.sleep(0)

    local result, err = assert(fronts[1]):awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')
    lt.assertEquals('技能带上了', true, #assert(result.skills) > 0)
    lt.assertEquals('面板带上了', 1, #assert(result.panels))
    lt.assertEquals('面板的名字对', '测面板', assert(result.panels)[1].name)
end)

---@async
lt.test('快照：展示用文本按定义收（选没选将、出没出牌都不影响）', function ()
    local game, players, fronts = support.newPackageGame()
    moe.await.sleep(0)

    local result, err = assert(fronts[1]):awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')

    ---@type table<string, string>
    local texts = {}
    for _, one in ipairs(assert(result.texts)) do
        texts[one.name] = one.text
    end
    lt.assertEquals('文本是定义级的：没选将也有技能文本', true, (texts['仁德'] or ''):find('至少一张手牌') ~= nil)
    lt.assertEquals('主公技没挂上也有它的文本', true, (texts['激将'] or ''):find('主公技') ~= nil)
    lt.assertEquals('没声明描述的定义不进表', nil, texts['杀'])
end)

---@async
lt.test('快照：要一份整局快照（牌 + 玩家）', function ()
    local game, players, fronts = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    game:getZone('弃牌'):accept(game:createCard('闪'))
    me.custom.heroName = '刘备'
    me:setCustomVisible('heroName', true)
    you.custom.heroName = '曹操'
    -- 让下一笔调度把增量发完，账里才有那张牌
    moe.await.sleep(0)

    game.turnPlayer = me
    local phase <close> = game:enterPhase(me, '出牌')

    local result, err = assert(fronts[1]):awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')

    lt.assertEquals('两个玩家都在', 2, #result.players)
    lt.assertEquals('第一个是自己', me.id, result.players[1].base.id)
    lt.assertEquals('座位号对得上', 1, result.players[1].base.seat)
    lt.assertEquals('公开的自定义数据带上了', '刘备', result.players[1].custom.heroName)
    lt.assertEquals('别人没公开的不带', nil, result.players[2].custom.heroName)

    lt.assertEquals('牌也带上了', 1, #result.cards)
    lt.assertEquals('牌面在', '闪', assert(result.cards[1].face).name)
    lt.assertEquals('区域是弃牌堆', '弃牌#0', result.cards[1].zone)
    lt.assertEquals('带上当前回合角色', me.id, result.turnPlayer)
    lt.assertEquals('带上当前阶段', '出牌', result.phase)
end)

---@async
lt.test('快照：各人看到的自定义数据不一样', function ()
    local _, players, fronts = newGame()
    local me = assert(players[1])
    -- 只声明给本人看：可见性由逐键账本定，不声明就谁都不见
    me:setCustomVisible('heroName', me)
    me.custom.heroName = '刘备'

    local mine,  mineErr  = assert(fronts[1]):awaitRequest('Game.SnapShot', {})
    local yours, yoursErr = assert(fronts[2]):awaitRequest('Game.SnapShot', {})
    lt.assertEquals('自己没出错', nil, mineErr)
    lt.assertEquals('别人也没出错', nil, yoursErr)
    assert(mine, '没拿到快照')
    assert(yours, '没拿到快照')
    lt.assertEquals('声明给他看的看得见', '刘备', mine.players[1].custom.heroName)
    lt.assertEquals('没声明的不给别人看', nil, yours.players[1].custom.heroName)
end)

---@async
lt.test('快照：还没入座的连接要不到（回的是具体错误）', function ()
    newGame()
    local front = select(1, connect())
    local result, err = front:awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('错在哪说清楚', '这条连接还没入座', err.message)
end)

---@async
lt.test('快照：还没开局要不到（回的是具体错误）', function ()
    local saved = moe.snapshot._game
    moe.snapshot._game = nil

    local front = select(1, connect())
    local result, err = front:awaitRequest('Game.SnapShot', {})

    moe.snapshot._game = saved
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码', moe.jsonrpc.INVALID_REQUEST, assert(err).code)
    lt.assertEquals('错在哪说清楚', '还没开局', err.message)
end)

---@async
lt.test('快照：按视角带上属性（没声明过可见性的不下发）', function ()
    local game, players, fronts = support.newPackageGame()
    game:fire('游戏-开始')

    local result, err = assert(fronts[1]):awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没出错', nil, err)
    assert(result, '没拿到快照')

    local me = assert(players[1])
    ---@type Proto.Attribute?
    local hp = nil
    ---@type Proto.Attribute?
    local range = nil
    for _, one in ipairs(result.players[1].attributes) do
        if one.name == '体力' then
            hp = one
        elseif one.name == '攻击范围' then
            range = one
        end
    end
    assert(hp, '体力没带上')
    lt.assertEquals('体力值就是现读的那个', me:getAttr('体力'), hp.value)
    lt.assertEquals('没声明过可见性的不下发', nil, range)
end)
