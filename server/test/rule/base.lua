local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'overlay-probe'

---@param sources? string[]
---@param items? string[]
---@return Game
local function newGame(sources, items)
    return moe.game.create {
        seats    = 4,
        random   = moe.random.create(1),
        sources  = sources,
        packages = items,
    }
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return fun() # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return function ()
        fs.remove_all(probeDir)
    end
end

---@param player Player
---@return Attributes
local function attributes(player)
    return player:getAttributes()
end

---@param game Game
---@return integer # 当前牌表的总张数（逐张表：数表长）
local function totalCards(game)
    return #assert(game.rule.cardTable, '没有牌表')
end

lt.test('基础：规则数值后者覆盖前者', function ()
    local probe <close> = useProbe()
    write('覆盖/配置.lua', 'rule.defaultHp = 6')

    local game = newGame()
    lt.assertEquals('默认体力来自基础包（它默认加载，不需要写进清单）', 5, game.rule.defaultHp)

    moe.loader.install(game, {
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '覆盖' },
    })

    lt.assertEquals('后加载的包覆盖了先前的值', 6, game.rule.defaultHp)
end)

lt.test('基础：换掉共享袋里的表就按新的走（读的时候才取）', function ()
    local run = support.start {
        packages = { '身份场', '标准' },
        count    = 4,
        beforeStart = function (game)
            game.rule.defaultDrawCount = 3
            game.rule.cardTable = { { name = '杀', suit = '黑桃', point = 1 } }
        end,
    }

    lt.assertEquals('改字段当场生效', 3, attributes(run.players[1]):get('摸牌数'))
    lt.assertEquals('换整张表当场生效', 1, assert(run.game:getZone('抽牌'), '没有抽牌'):count())
end)

lt.test('基础：清空重载后不保留', function ()
    local game = newGame(nil, { '标准' })
    lt.assertEquals('标准包提供了牌表', true, game.rule.cardTable ~= nil)
    lt.assertEquals('默认包的值也在', 5, game.rule.defaultHp)

    moe.loader.install(game, { packages = { '身份场' } })

    lt.assertEquals('上一轮非默认包的值被清空', nil, game.rule.cardTable)
    lt.assertEquals('默认包总会重新加载，所以值还在', 5, game.rule.defaultHp)
end)

lt.test('基础：未设置的名字读到不存在', function ()
    local game = newGame()

    lt.assertEquals('读到不存在', nil, game:getValue('根本没有这个名字'))

    game:setValue('临时', 1)
    local snapshot = game:getValues()
    lt.assertEquals('取全部数值里能看到已设置的', 1, snapshot['临时'])

    game:setValue('临时', 2)
    lt.assertEquals('快照不跟随后续修改', 1, snapshot['临时'])
    lt.assertEquals('但规则数值里已经是新的', 2, game:getValue('临时'))
end)

lt.test('基础：体力初值等于上限', function ()
    local run = support.start { packages = { '身份场', '标准' }, count = 4 }

    for i = 1, 4 do
        lt.assertEquals('第 {} 个玩家的体力等于上限' % { i }, attributes(run.players[i]):get('体力上限'), attributes(run.players[i]):get('体力'))
    end
end)

lt.test('基础：体力上限跟着覆盖后的规则数值', function ()
    local probe <close> = useProbe()
    write('我的配置/配置.lua', 'rule.defaultHp = 3')

    local run = support.start {
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '我的配置', '身份场', '标准' },
        count    = 4,
    }

    lt.assertEquals('用了覆盖后的上限', 3, attributes(run.players[2]):get('体力上限'))
    lt.assertEquals('体力也跟着走', 3, attributes(run.players[2]):get('体力'))
end)

lt.test('基础：按牌表建出牌堆', function ()
    local run = support.start { packages = { '身份场', '标准' }, count = 4 }

    local deck = assert(run.game:getZone('抽牌'), '没有建出抽牌')
    lt.assertEquals('张数等于牌表总数', totalCards(run.game), deck:count())
    lt.assertEquals('每张牌都带牌名', '杀', deck:list()[1].name)
    lt.assertEquals('弃牌也建好了', true, run.game:getZone('弃牌') ~= nil)
    lt.assertEquals('抽牌堆是暗的（谁都看不见牌面）', false, deck:isVisibleTo(run.players[1]))
    lt.assertEquals('手牌只有持有者看得见', true, assert(run.players[1]):getZone('手牌'):isVisibleTo(run.players[1]))
    lt.assertEquals('别人的手牌看不见', false, assert(run.players[1]):getZone('手牌'):isVisibleTo(assert(run.players[2])))
end)

lt.test('基础：洗牌可复现', function ()
    ---@param run Test.RuleSupport
    ---@return string[] # 抽牌上的牌名序列
    local function deckLabels(run)
        local deck = assert(run.game:getZone('抽牌'), '没有抽牌')
        ---@type string[]
        local result = {}
        for i, card in ipairs(deck:list()) do
            result[i] = card.name
        end
        return result
    end

    local first  = deckLabels(support.start { packages = { '身份场', '标准' }, count = 4, seed = 20260919 })
    local second = deckLabels(support.start { packages = { '身份场', '标准' }, count = 4, seed = 20260919 })

    lt.assertEquals('两次张数一致', #first, #second)
    lt.assertEquals('同一 seed 洗出的顺序一致', table.concat(first, ','), table.concat(second, ','))
end)

lt.test('基础：牌堆里各种牌的张数与牌表一致', function ()
    local run = support.start { packages = { '身份场', '标准' }, count = 4 }

    ---@type table<string, integer>
    local counts = {}
    for _, card in ipairs(assert(run.game:getZone('抽牌')):list()) do
        local name = card.name
        counts[name] = (counts[name] or 0) + 1
    end

    lt.assertEquals('杀 30 张', 30, counts['杀'])
    lt.assertEquals('闪 15 张', 15, counts['闪'])
    lt.assertEquals('桃 8 张', 8, counts['桃'])
    lt.assertEquals('无懈可击 4 张', 4, counts['无懈可击'])
    lt.assertEquals('万箭齐发 1 张', 1, counts['万箭齐发'])
    lt.assertEquals('借刀杀人 2 张', 2, counts['借刀杀人'])
end)

lt.test('基础：牌表里每张都有合法的花色与点数', function ()
    local run       = support.start { packages = { '身份场', '标准' }, count = 4 }
    local cardTable = assert(run.game.rule.cardTable, '没有牌表')
    ---@type table<string, true>
    local suits = { ['黑桃'] = true, ['红桃'] = true, ['梅花'] = true, ['方块'] = true }

    local bad = 0
    for _, entry in ipairs(cardTable) do
        if not suits[entry.suit] or math.type(entry.point) ~= 'integer' or entry.point < 1 or entry.point > 13 then
            bad = bad + 1
        end
    end

    lt.assertEquals('牌面全都是合法取值', 0, bad)
    lt.assertEquals('草稿牌表共 107 张', 107, #cardTable)

    local deck = assert(run.game:getZone('抽牌'), '没有建出抽牌')
    local card = deck:list()[1]
    lt.assertEquals('牌堆里的牌带着花色', true, card.suit ~= nil)
    lt.assertEquals('牌堆里的牌带着点数', true, card.point ~= nil)
end)

lt.test('基础：没有牌表时牌堆是空的', function ()
    lt.expectErrors(1)
    local run = support.start { count = 4 }

    lt.assertEquals('抽牌区由内核建好了', true, run.game:getZone('抽牌') ~= nil)
    lt.assertEquals('但没有牌（回调报错被时机机制记录）', 0, run.game:getZone('抽牌'):count())
end)

lt.test('基础：体力可以降到负数，写值会被钳到上限', function ()
    local run    = support.start { packages = { '身份场', '标准' }, count = 4 }
    local player = run.players[2]

    lt.assertEquals('开局体力等于上限', 5, player:getAttr('体力'))

    player:setAttr('体力', 99)
    lt.assertEquals('超过上限被钳到上限', 5, player:getAttr('体力'))

    player:setAttr('体力', -2)
    lt.assertEquals('体力可以为负（濒死要用）', -2, player:getAttr('体力'))

    player:addAttr('体力上限', 1)
    lt.assertEquals('抬上限不动体力', -2, player:getAttr('体力'))
end)

lt.test('基础：体力的便捷读法', function ()
    local run    = support.start { packages = { '身份场', '标准' }, count = 4 }
    local player = run.players[2]

    lt.assertEquals('当前体力', 5, player:getHp())
    lt.assertEquals('体力上限', 5, player:getMaxHp())
    lt.assertEquals('满血时没有缺失', 0, player:getLostHp())

    player:setAttr('体力', 3)
    lt.assertEquals('掉血后当前体力', 3, player:getHp())
    lt.assertEquals('上限不动', 5, player:getMaxHp())
    lt.assertEquals('缺失 = 上限 − 当前', 2, player:getLostHp())

    player:addAttr('体力上限', 1)
    lt.assertEquals('抬上限后缺失跟着变大（算出来的，不是存的）', 3, player:getLostHp())
end)

lt.test('基础：身上有没有牌（hasCard）', function ()
    local run    = support.start { packages = { '标准' }, count = 2 }
    local player = run.players[1]

    lt.assertEquals('空身时没有牌', false, player:hasCard())

    local slash  = run.game:createCard('杀', '黑桃', 7)
    local weapon = run.game:createCard('丈八蛇矛', '黑桃', 12)
    assert(player:getZone('手牌')):accept(slash)
    assert(player:getZone('手牌')):accept(weapon)

    lt.assertEquals('手牌里有牌', true, player:hasCard())
    lt.assertEquals('指名手牌', true, player:hasCard('手牌'))
    lt.assertEquals('传区对象也一样', true, player:hasCard(assert(player:getZone('手牌'))))
    lt.assertEquals('空着的判定区没有牌', false, player:hasCard('判定'))

    run.game:moveCard(weapon, '弃牌')
    lt.assertEquals('只挪走一张也还是有牌', true, player:hasCard())

    run.game:moveCard(slash, '弃牌')
    lt.assertEquals('牌都挪走后身上就没有了', false, player:hasCard())
    lt.assertEquals('局上的弃牌堆按名字也解析得到', true, player:hasCard('弃牌'))
    lt.assertEquals('认不出的区名当没有', false, player:hasCard('没有这个区'))

    run.game:moveCard(weapon, assert(player:getZone('武器')))
    lt.assertEquals('装备子区里的牌也算', true, player:hasCard())
end)

lt.test('基础：属性系统由局持有，随清空重载重建', function ()
    local game = newGame(nil, { '身份场', '标准' })

    local before = game:getAttributeSystem()
    lt.assertEquals('包已经定义过属性', true, before ~= nil)

    moe.loader.install(game, { packages = { '身份场', '标准' } })

    lt.assertEquals('重载后换了一个属性系统', false, game:getAttributeSystem() == before)
end)
