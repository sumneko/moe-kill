local lt = require 'test.ltest'

---@param seed? integer
---@return Core.Room
local function newRoom(seed)
    local desk   = moe.core.desk.create(4)
    local random = moe.core.random.create(seed or 1)
    return moe.core.room.create { desk = desk, random = random }
end

---@param zone Core.Zone
---@return string
local function labels(zone)
    ---@type string[]
    local result = {}
    for i, card in ipairs(zone:list()) do
        result[i] = card:getLabel()
    end
    return table.concat(result, ',')
end

lt.test('场地：持一张桌子与一个随机源', function ()
    local desk   = moe.core.desk.create(4)
    local random = moe.core.random.create(1)
    local room   = moe.core.room.create { desk = desk, random = random }

    lt.assertEquals('取回同一张桌子', desk, room:getDesk())
    lt.assertEquals('取回同一个随机源', random, room:getRandom())

    ---@type any
    local missingRandom = { desk = desk }
    lt.assertError('缺桌子或随机源报错', function ()
        moe.core.room.create(missingRandom)
    end)
end)

lt.test('场地：按名字建牌区并取回', function ()
    local room = newRoom()
    local deck = room:createZone('抽牌堆', true)

    lt.assertEquals('返回的就是登记的那个牌区', deck, room:getZone('抽牌堆'))
    lt.assertEquals('没建过的名字取不到', nil, room:getZone('没有这个区'))
    lt.assertEquals('列举按创建顺序', 1, #room:getZones())
    lt.assertError('同名牌区报错', function ()
        room:createZone('抽牌堆', true)
    end)
    lt.assertError('名字不能为空', function ()
        room:createZone('')
    end)
end)

lt.test('场地：默认建无序牌区，ordered 建有序牌区', function ()
    local room = newRoom()

    lt.assertEquals('默认是无序的', 'zone', room:createZone('弃牌堆').kind)
    lt.assertEquals('ordered 是有序的', 'orderedZone', room:createZone('抽牌堆', true).kind)
end)

lt.test('场地：建牌带牌名', function ()
    local room = newRoom()

    lt.assertEquals('牌名写进不透明标签', '杀', room:createCard('杀'):getLabel())
    lt.assertEquals('每次建出的是新实例', false, room:createCard('杀') == room:createCard('杀'))
    lt.assertError('牌名不能为空', function ()
        room:createCard('')
    end)
end)

lt.test('场地：有序牌区洗牌不用再传随机源', function ()
    local first  = newRoom(42)
    local second = newRoom(42)

    local deckA = first:createZone('抽牌堆', true)
    local deckB = second:createZone('抽牌堆', true)
    for i = 1, 10 do
        deckA:put(first:createCard('牌' .. i))
        deckB:put(second:createCard('牌' .. i))
    end

    deckA:shuffle()
    deckB:shuffle()

    lt.assertEquals('张数不变', 10, deckA:count())
    lt.assertEquals('同种子同内容洗出同样顺序', labels(deckA), labels(deckB))
end)

lt.test('场地：没绑定随机源的有序牌区洗牌要传随机源', function ()
    local zone = moe.core.orderedZone.create()
    zone:put(moe.core.card.create('甲'))

    lt.assertError('省略随机源报错', function ()
        zone:shuffle()
    end)

    zone:shuffle(moe.core.random.create(1))
    lt.assertEquals('传了随机源就能洗', 1, zone:count())
end)
