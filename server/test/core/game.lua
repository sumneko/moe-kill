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
    local deck = game:createZone('抽牌', true)

    lt.assertEquals('返回的就是登记的那个牌区', deck, game:getZone('抽牌'))
    lt.assertEquals('没建过的名字取不到', nil, game:getZone('没有这个区'))
    lt.assertEquals('列举按创建顺序', 1, #game:getZones())
    lt.assertError('同名牌区报错', function ()
        game:createZone('抽牌', true)
    end)
    lt.assertError('名字不能为空', function ()
        game:createZone('')
    end)
end)

lt.test('局：默认建无序牌区，ordered 建有序牌区', function ()
    local game = newGame()

    lt.assertEquals('默认是无序的', 'zone', game:createZone('弃牌').kind)
    lt.assertEquals('ordered 是有序的', 'orderedZone', game:createZone('抽牌', true).kind)
end)

lt.test('局：建牌带牌名', function ()
    local game = newGame()

    lt.assertEquals('牌名写进不透明标签', '杀', game:createCard('杀'):getLabel())
    lt.assertEquals('每次建出的是新实例', false, game:createCard('杀') == game:createCard('杀'))
    lt.assertError('牌名不能为空', function ()
        game:createCard('')
    end)
end)

lt.test('局：发号给牌，将来也给技能', function ()
    local game = newGame()

    lt.assertEquals('号从 1 开始', 1, game:createCard('杀'):getId())
    lt.assertEquals('建牌依次取号', 2, game:createCard('闪'):getId())

    local first  = game:nextId()
    local second = game:nextId()
    lt.assertEquals('技能自己取的号接着牌的号往下走', 3, first)
    lt.assertEquals('取的号不重复', 4, second)
    lt.assertEquals('取号也推着建牌往下走', 5, game:createCard('桃'):getId())

    game:resetContent()
    lt.assertEquals('重装规则内容不重置号源', 6, game:createCard('桃'):getId())

    lt.assertEquals('另一局从头开始', 1, newGame():createCard('桃'):getId())
end)

lt.test('局：把牌挪进某个牌区', function ()
    local game  = newGame()
    local hand  = game:createZone('手牌')
    local pile  = game:createZone('弃牌')
    local stage = game:createZone('处理')
    local jink  = game:createCard('闪')
    local slash = game:createCard('杀')
    hand:put(jink)
    hand:put(slash)

    game:moveCard({ jink, slash }, '弃牌')

    lt.assertEquals('手牌空了', 0, hand:count())
    lt.assertEquals('弃牌按给出的顺序收到', '闪,杀', labels(pile))
    lt.assertEquals('牌自己也知道换区了', pile, jink:getZone())

    game:moveCard(jink, { '处理', '弃牌' })

    lt.assertEquals('单张牌也能挪，停在最后一站', pile, jink:getZone())
    lt.assertEquals('一串区名 = 依次经过，中间那站不留牌', 0, stage:count())
    lt.assertEquals('没被点名的牌没被带着走', slash, pile:list()[1])
end)

lt.test('局：挪牌时的几种失败记在效果上，且不改状态', function ()
    local game = newGame()
    local hand = game:createZone('手牌')
    local pile = game:createZone('弃牌')
    local card = game:createCard('闪')
    hand:put(card)
    lt.clearErrors()

    lt.assertFailed('局上没有这个牌区', game:moveCard(card, '没有这个区'))
    lt.assertFailed('路径里有一站不存在', game:moveCard(card, { '弃牌', '没有这个区' }))

    lt.assertEquals('失败都被收下', 2, #lt.errors)
    lt.clearErrors()
    lt.assertEquals('失败后牌还在原处', 1, hand:count())
    lt.assertEquals('失败后归属没变', hand, card:getZone())
    lt.assertEquals('弃牌没被碰到', 0, pile:count())
end)

lt.test('局：没有归属的牌也能挪，第一站当作放进去', function ()
    local game  = newGame()
    local stage = game:createZone('处理')
    local pile  = game:createZone('弃牌')
    local card  = game:createCard('闪')

    game:moveCard(card, { '处理', '弃牌' })

    lt.assertEquals('进了最后一站', pile, card:getZone())
    lt.assertEquals('中间那站不留牌', 0, stage:count())
    lt.assertEquals('弃牌里有它', card, pile:list()[1])
end)

lt.test('局：挪牌可以直接给牌区对象', function ()
    local game = newGame()
    local hand = game:createZone('手牌')
    local pile = game:createZone('弃牌')
    local card = game:createCard('闪')
    hand:put(card)

    game:moveCard(card, pile)

    lt.assertEquals('进了给的那个牌区', pile, card:getZone())
    lt.assertEquals('源区空了', 0, hand:count())
end)

lt.test('局：牌区名先找当前回合角色，再找局上的牌区', function ()
    local game = newGame()
    local gameHand = game:createZone('手牌')
    local lord = moe.player.create { attributes = game:getAttributeSystem():createInstance() }
    game.desk:sit(1, lord)
    lord:addZone('手牌')
    lord:addZone('装备')
    local lordHand = assert(lord:getZone('手牌'), '没建出手牌区')
    local card = game:createCard('闪')
    gameHand:put(card)

    game.turnPlayer = lord
    game:moveCard(card, '手牌')
    lt.assertEquals('优先落进当前回合角色的同名区', lordHand, card:getZone())
    lt.assertEquals('局上的同名区没被碰到', 0, gameHand:count())

    game:moveCard(card, '装备')
    lt.assertEquals('只有玩家身上有的区名也能落', lord:getZone('装备'), card:getZone())

    game.turnPlayer = nil
    game:moveCard(card, '手牌')
    lt.assertEquals('没有回合角色时落回局上的区', gameHand, card:getZone())

    lt.assertFailed('两边都没有的区名照样失败', game:moveCard(card, '没有这个区'))
    lt.assertEquals('失败后牌还在原处', gameHand, card:getZone())
    lt.clearErrors()
end)

lt.test('局：有序牌区洗牌不用再传随机源', function ()
    local first  = newGame(42)
    local second = newGame(42)

    local deckA = first:createZone('抽牌', true)
    local deckB = second:createZone('抽牌', true)
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
    zone:put(lt.card('甲'))

    lt.assertError('省略随机源报错', function ()
        zone:shuffle()
    end)

    zone:shuffle(moe.random.create(1))
    lt.assertEquals('传了随机源就能洗', 1, zone:count())
end)

lt.test('定义：阶段限额随定义走，没声明就是 1000', function ()
    local game = moe.game.create {
        desk     = moe.desk.create(4),
        random   = moe.random.create(1),
        packages = { '标准' },
    }

    lt.assertEquals('标准包的【杀】声明了出牌阶段限一次', 1, game:getCard('杀'):getLimit('出牌'))
    lt.assertEquals('没声明过的阶段是 1000', 1000, game:getCard('杀'):getLimit('摸牌'))
    lt.assertEquals('别的牌没声明就是 1000', 1000, game:getCard('闪'):getLimit('出牌'))

    game:getCard('杀'):limit('出牌', 2)

    lt.assertEquals('后写的覆盖先写的', 2, game:getCard('杀'):getLimit('出牌'))
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
