local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local DECK = { '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛' }

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'zone-probe'

local probeSource = [[
Card '被动牌'
    : on('被动', function (card, zone, host)
        game:setValue('应用', (game:getValue('应用') or 0) + 1)
        host:bindGC(function ()
            game:setValue('撤销', (game:getValue('撤销') or 0) + 1)
        end)
    end)
Card '装备样'
    : on('进入区域', function (card, zone)
        if zone.owner then
            card:enablePassive()
        end
    end)
    : on('离开区域', function (card, zone)
        if zone.owner then
            card:disablePassive()
        end
    end)
    : on('被动', function (card, zone, host)
        game:setValue('装备样应用', (game:getValue('装备样应用') or 0) + 1)
        host:bindGC(function ()
            game:setValue('装备样撤销', (game:getValue('装备样撤销') or 0) + 1)
        end)
    end)
]]

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@return Game
local function newProbeGame()
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), probeSource)
    assert(ok, err)
    return moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

---@param zone Zone
---@param source string[]
---@return Card[]
local function fill(zone, source)
    local cards = {}
    for i = 1, #source do
        cards[i] = lt.card(source[i])
        zone:accept(cards[i])
    end
    return cards
end

---@param list Card[]
---@return string
local function labels(list)
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i].name)
    end
    return table.concat(names, ',')
end

---@param zone Zone
---@return string
local function zoneLabels(zone)
    return labels(zone:list())
end

---@param seed integer
---@return string
local function shuffledLabels(seed)
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(seed))
    return zoneLabels(zone)
end

lt.test('牌区：放入后计数与查看正确', function ()
    local zone  = lt.zone()
    local cards = fill(zone, { '甲', '乙', '丙' })

    lt.assertEquals('放入后计数', 3, zone:count())
    lt.assertEquals('顺序与放入一致', '甲,乙,丙', zoneLabels(zone))
    lt.assertEquals('查看第二张', cards[2], zone:peek(2))
end)

lt.test('牌区：列举返回副本，清空清掉全部', function ()
    local zone = lt.zone()
    fill(zone, { '甲', '乙' })

    local snapshot = zone:list()
    snapshot[1] = nil

    lt.assertEquals('修改副本不影响牌区', 2, zone:count())
    lt.assertEquals('再列举仍是原内容', '甲,乙', zoneLabels(zone))

    lt.assertEquals('清空返回被清掉的张数', 2, zone:clear())
    lt.assertEquals('清空后计数', 0, zone:count())
    lt.assertEquals('清空后列举为空', '', zoneLabels(zone))
end)

lt.test('牌区：空区 / 越界 / 序号非整数都给空', function ()
    local zone = lt.zone()

    lt.assertEquals('空区查看给空', nil, zone:peek(1))

    fill(zone, { '甲' })
    lt.assertEquals('越界查看给空（0 也不行）', nil, zone:peek(0))

    ---@type any
    local notInteger = 1.5
    lt.assertEquals('序号非整数也给空', nil, zone:peek(notInteger))

    lt.assertEquals('查看不动内容', '甲', zoneLabels(zone))
end)

lt.test('牌区：kind 只用来区分子类', function ()
    lt.assertEquals('基类的 kind', 'zone', lt.zone().kind)
    lt.assertEquals('有序子类的 kind', 'orderedZone', lt.orderedZone().kind)
end)

lt.test('牌区：禁用可以叠层，逐层撤销才恢复', function ()
    local zone = lt.zone()

    lt.assertEquals('初始为启用', true, zone:isEnabled())

    local first  = zone:disable()
    local second = zone:disable()
    lt.assertEquals('叠了两层：不是启用', false, zone:isEnabled())

    first()
    first()
    lt.assertEquals('同一只撤销函数重复调只减一层', false, zone:isEnabled())

    second()
    lt.assertEquals('两层都撤掉才恢复', true, zone:isEnabled())
end)

lt.test('牌区：禁用不再拦搬入搬出与清空', function ()
    local zone = lt.zone()
    fill(zone, { '甲' })
    zone:disable()

    lt.assertEquals('照收', true, (zone:accept(lt.card('乙'))))
    lt.assertEquals('收进来了', '甲,乙', zoneLabels(zone))
    lt.assertEquals('照清', 2, zone:clear())
    lt.assertEquals('清空了', 0, zone:count())
end)

lt.test('牌区：禁用压住区里的牌，恢复时重新应用', function ()
    local guard <close> = useProbe()
    local game  = newProbeGame()
    local zone  = moe.zone.create(game)
    local card  = game:createCard('被动牌')
    zone:accept(card)

    card:enablePassive()
    lt.assertEquals('先启用：应用一次', 1, game:getValue('应用'))

    local undo = zone:disable()
    lt.assertEquals('禁用把牌上的被动压掉', 1, game:getValue('撤销'))

    undo()
    lt.assertEquals('恢复时重新应用', 2, game:getValue('应用'))
end)

lt.test('牌区：禁用期间进区的牌也被压住', function ()
    local guard <close> = useProbe()
    local game  = newProbeGame()
    local zone  = moe.zone.create(game)
    local undo  = zone:disable()
    local card  = game:createCard('被动牌')

    zone:accept(card)
    card:enablePassive()
    lt.assertEquals('压制层数没到 0：一次都没应用', nil, game:getValue('应用'))

    undo()
    lt.assertEquals('区恢复：应用一次', 1, game:getValue('应用'))
end)

lt.test('牌区：禁用期间装进来的牌不会被进区钩子松开', function ()
    local guard <close> = useProbe()
    local game   = newProbeGame()
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
    player:addZone('武器')
    local zone = assert(player:getZone('武器'))
    local undo = zone:disable()
    local card = game:createCard('装备样')

    zone:accept(card)

    lt.assertEquals('进区钩子松开了一层，区级那层还在：没应用过', nil, game:getValue('装备样应用'))
    lt.assertEquals('也没有东西要撤', nil, game:getValue('装备样撤销'))

    undo()
    lt.assertEquals('区恢复：应用一次', 1, game:getValue('装备样应用'))
end)

lt.test('牌区：从禁用区拿走时不再重新应用，区级那层也摘掉', function ()
    local guard <close> = useProbe()
    local game   = newProbeGame()
    local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
    player:addZone('武器')
    local zone  = assert(player:getZone('武器'))
    local other = assert(game:getZone('弃牌'))
    local card  = game:createCard('装备样')
    zone:accept(card)
    lt.assertEquals('先装上：应用一次', 1, game:getValue('装备样应用'))

    local undo = zone:disable()
    other:accept(card)

    lt.assertEquals('离区钩子先停用 ⇒ 没有重新应用', 1, game:getValue('装备样应用'))
    lt.assertEquals('撤销只发生过禁用那一次', 1, game:getValue('装备样撤销'))

    undo()
    lt.assertEquals('区恢复时牌已不在里面：不动它', 1, game:getValue('装备样应用'))

    zone:accept(card)
    lt.assertEquals('区已恢复，再装回来又应用一次（说明区级那层确实已摘掉）', 2, game:getValue('装备样应用'))
end)

lt.test('有序牌区：相同随机源洗出相同顺序', function ()
    lt.assertEquals('同种子同顺序', shuffledLabels(20260919), shuffledLabels(20260919))
    lt.assertNotEquals('异种子异顺序', shuffledLabels(20260919), shuffledLabels(20260920))
    lt.assertNotEquals('洗牌确实改变顺序', table.concat(DECK, ','), shuffledLabels(20260919))
end)

lt.test('有序牌区：依次取顶与洗牌后顺序一致', function ()
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(7))

    local expected = zoneLabels(zone)
    local drawn    = {}
    while zone:count() > 0 do
        drawn[#drawn + 1] = tostring(assert(zone:draw(1)[1]).name)
    end

    lt.assertEquals('取顶顺序与洗牌后一致', expected, table.concat(drawn, ','))
    lt.assertEquals('取完后计数为 0', 0, zone:count())
    lt.assertEquals('取空后再取给空列表', 0, #zone:draw(1))
end)

lt.test('有序牌区：从顶取 n 张，不够就少给', function ()
    local zone = lt.orderedZone()
    fill(zone, { '甲', '乙', '丙' })

    local two = zone:draw(2)
    lt.assertEquals('取到 2 张', 2, #two)
    lt.assertEquals('取的是前两张', '甲,乙', labels(two))
    lt.assertEquals('区里剩 1 张', '丙', zoneLabels(zone))

    local rest = zone:draw(5)
    lt.assertEquals('再多要也只有 1 张', 1, #rest)
    lt.assertEquals('要不到不报错', '', zoneLabels(zone))

    lt.assertEquals('空区取到 0 张', 0, #zone:draw(1))
end)

lt.test('有序牌区：取空了会调不足回调，补到就接着取', function ()
    local zone  = lt.orderedZone()
    local stock = lt.zone()
    fill(stock, { '甲', '乙', '丙' })

    ---@type integer
    local times = 0
    zone:setShortageHandler(function (target)
        times = times + 1
        lt.assertEquals('回调收到的是这个区', zone, target)
        for _, card in ipairs(stock:list()) do
            zone:accept(card)
        end
    end)

    local cards = zone:draw(3)

    lt.assertEquals('只调了一次', 1, times)
    lt.assertEquals('取到 3 张', 3, #cards)
    lt.assertEquals('按补进来的顺序取', '甲,乙,丙', labels(cards))
end)

lt.test('有序牌区：回调补不到牌就少给', function ()
    local zone = lt.orderedZone()

    ---@type integer
    local times = 0
    zone:setShortageHandler(function ()
        times = times + 1
    end)

    local cards = zone:draw(2)

    lt.assertEquals('调了一次', 1, times)
    lt.assertEquals('一张都没取到', 0, #cards)
end)

lt.test('有序牌区：没挂回调时取空就少给', function ()
    local zone = lt.orderedZone()

    lt.assertEquals('要 3 张拿到 0 张', 0, #zone:draw(3))
end)

lt.test('有序牌区：洗牌必须传入随机源', function ()
    local zone = lt.orderedZone()
    fill(zone, DECK)

    ---@type any
    local notRandom = {}

    ---@type any
    local noRandom = nil

    lt.assertError('随机源类型不对', function () zone:shuffle(notRandom) end)
    lt.assertError('没有随机源', function () zone:shuffle(noRandom) end)
    lt.assertEquals('失败后顺序不变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('有序牌区：禁用后照洗（禁用是逻辑状态，不拦搬运）', function ()
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:disable()

    zone:shuffle(moe.random.create(20260919))
    lt.assertEquals('洗得动', shuffledLabels(20260919), zoneLabels(zone))
end)

lt.test('牌区：默认对所有人可见，设成暗区后只有持有者看得见', function ()
    local game   = moe.game.create { seats = 2, random = moe.random.create(1) }
    local system = moe.attribute.create()
    local mine   = moe.player.create(game, { attributes = system:createInstance() })
    local other  = moe.player.create(game, { attributes = system:createInstance() })

    local open = moe.zone.create(game)
    lt.assertEquals('默认对所有人可见', true, open:isVisibleTo(other))

    local hand = mine:getZone('手牌')
    hand:setVisible(false)

    lt.assertEquals('持有者自己看得见', true, hand:isVisibleTo(mine))
    lt.assertEquals('别人看不见', false, hand:isVisibleTo(other))

    local nobody = moe.zone.create(game)
    nobody:setVisible(false)
    lt.assertEquals('没有归属的暗区：谁都看不见', false, nobody:isVisibleTo(mine))
end)
