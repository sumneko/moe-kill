local lt = require 'test.ltest'

---@param seed? integer
---@return Game
local function newGame(seed)
    local desk   = moe.desk.create(4)
    local random = moe.random.create(seed or 1)
    return moe.game.create { desk = desk, random = random }
end

---@param zone Zone
---@return string
local function labels(zone)
    ---@type string[]
    local result = {}
    for i, card in ipairs(zone:list()) do
        result[i] = card:getLabel()
    end
    return table.concat(result, ',')
end

lt.test('局：持一张桌子与一个随机源', function ()
    local desk   = moe.desk.create(4)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }

    lt.assertEquals('取回同一张桌子', desk, game.desk)
    lt.assertEquals('取回同一个随机源', random, game.random)
    lt.assertEquals('两者也是公开字段', true, game.desk == desk and game.random == random)

    ---@type any
    local missingRandom = { desk = desk }
    lt.assertError('缺桌子或随机源报错', function ()
        moe.game.create(missingRandom)
    end)
end)

lt.test('局：按名字建牌区并取回', function ()
    local game = newGame()
    local deck = game:createZone('抽牌堆', true)

    lt.assertEquals('返回的就是登记的那个牌区', deck, game:getZone('抽牌堆'))
    lt.assertEquals('没建过的名字取不到', nil, game:getZone('没有这个区'))
    lt.assertEquals('列举按创建顺序', 1, #game:getZones())
    lt.assertError('同名牌区报错', function ()
        game:createZone('抽牌堆', true)
    end)
    lt.assertError('名字不能为空', function ()
        game:createZone('')
    end)
end)

lt.test('局：默认建无序牌区，ordered 建有序牌区', function ()
    local game = newGame()

    lt.assertEquals('默认是无序的', 'zone', game:createZone('弃牌堆').kind)
    lt.assertEquals('ordered 是有序的', 'orderedZone', game:createZone('抽牌堆', true).kind)
end)

lt.test('局：建牌带牌名', function ()
    local game = newGame()

    lt.assertEquals('牌名写进不透明标签', '杀', game:createCard('杀'):getLabel())
    lt.assertEquals('每次建出的是新实例', false, game:createCard('杀') == game:createCard('杀'))
    lt.assertError('牌名不能为空', function ()
        game:createCard('')
    end)
end)

lt.test('局：有序牌区洗牌不用再传随机源', function ()
    local first  = newGame(42)
    local second = newGame(42)

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

lt.test('牌区：没绑定随机源的有序牌区洗牌要传随机源', function ()
    local zone = moe.orderedZone.create()
    zone:put(moe.card.create('甲'))

    lt.assertError('省略随机源报错', function ()
        zone:shuffle()
    end)

    zone:shuffle(moe.random.create(1))
    lt.assertEquals('传了随机源就能洗', 1, zone:count())
end)

lt.test('局：建局时装好规则', function ()
    local game = moe.game.create {
        desk     = moe.desk.create(4),
        random   = moe.random.create(1),
        packages = { '标准' },
    }

    lt.assertEquals('清单里的包已经装好', true, game:getValue('牌表') ~= nil)
    lt.assertEquals('默认加载的包也装了', 5, game:getValue('默认体力'))
    lt.assertEquals('属性系统也备好了', true, game:getAttributeSystem() ~= nil)
    lt.assertEquals('实际执行过的文件读得回来', true, #game.loadedFiles > 0)
end)

lt.test('局：两个局的规则互不影响', function ()
    local first  = newGame()
    local second = newGame()

    lt.assertEquals('两个局不是同一个对象', false, first == second)
    lt.assertEquals('属性系统也不是同一份', false, first:getAttributeSystem() == second:getAttributeSystem())

    moe.loader.install(first, { packages = { '标准' } })
    lt.assertEquals('改了第一个：第一个有牌表', true, first:getValue('牌表') ~= nil)
    lt.assertEquals('第二个不受影响', nil, second:getValue('牌表'))

    first:resetContent()
    lt.assertEquals('清空规则内容后数值没了', nil, first:getValue('牌表'))
    lt.assertEquals('桌子与随机源不受清空影响', true, first.desk ~= nil and first.random ~= nil)
    lt.assertEquals('牌区也不受清空影响', true, first:getZones() ~= nil)
end)

lt.test('装载器：重装复用局上记的来源与清单', function ()
    local game = newGame()
    lt.assertEquals('建局时用的是默认来源', './package/*', game.sources[1])

    moe.loader.install(game, { packages = { '标准' } })
    local loaded = moe.loader.install(game)

    lt.assertEquals('复用局上记的清单重新装了一遍', true, #loaded > 0)
    lt.assertEquals('内容照旧', true, game:getValue('牌表') ~= nil)
end)
