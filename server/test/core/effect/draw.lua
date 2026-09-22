local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'draw-bare'

---@return unknown # 配 <close> 用
local function useBareSources()
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

--- 一个不装任何内容包的局（连默认包也不装）：内核的机制在这里是「光杆」
---@return Game
---@return Player[]
local function newBareGame()
    local desk   = moe.desk.create(2)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        desk    = desk,
        random  = random,
        sources = { probeDir:string() .. '/*' },
    }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    return game, players
end

lt.test('摸牌：内核不碰牌区，只触发「摸牌」时机', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame()
    local deck = game:createZone('抽牌', true)
    players[1]:addZone('手牌')
    for _ = 1, 3 do
        deck:put(game:createCard('杀'))
    end

    ---@type Draw?
    local seen = nil
    game:on('摸牌', function (draw)
        seen = draw
    end)

    local draw = game:draw(players[1], 2)

    local ctx = assert(seen, '「摸牌」没有触发')
    lt.assertEquals('上下文就是这次摸牌', draw, ctx)
    lt.assertEquals('种类标识', 'draw', draw.kind)
    lt.assertEquals('摸牌的人可读', players[1], ctx.player)
    lt.assertEquals('摸几张可读', 2, ctx.count)
    lt.assertEquals('内核不碰抽牌区', 3, deck:count())
    lt.assertEquals('内核不碰手牌', 0, assert(players[1]:getZone('手牌')):count())
end)

lt.test('摸牌：没有订阅者时照常结完', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame()

    local draw = game:draw(players[1], 1)

    lt.assertEquals('返回这次摸牌', 'draw', draw.kind)
    lt.assertEquals('没有结果', nil, draw.result)
    lt.assertEquals('也没有失败', nil, draw.err)
end)

lt.test('摸牌：已阵亡的不摸、不触发时机', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame()
    local deck = game:createZone('抽牌', true)
    players[1]:addZone('手牌')
    deck:put(game:createCard('杀'))

    ---@type integer
    local fired = 0
    game:on('摸牌', function () fired = fired + 1 end)

    players[1]:setAlive(false)
    local draw = game:draw(players[1], 1)

    lt.assertEquals('没触发时机', 0, fired)
    lt.assertEquals('牌还在抽牌里', 1, deck:count())
    lt.assertEquals('手牌还是空的', 0, assert(players[1]:getZone('手牌')):count())
    lt.assertEquals('不算失败', nil, draw.err)
end)
