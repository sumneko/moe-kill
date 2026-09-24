local lt = require 'test.ltest'

local DECK = { '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛' }

---@param zone Zone
---@param source string[]
---@return Card[]
local function fill(zone, source)
    local cards = {}
    for i = 1, #source do
        cards[i] = lt.card(source[i])
        zone:put(cards[i])
    end
    return cards
end

---@param list Card[]
---@return string
local function labels(list)
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i]:getLabel())
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
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(seed))
    return zoneLabels(zone)
end

lt.test('牌区：放入与取出后计数正确', function ()
    local zone  = moe.zone.create()
    local cards = fill(zone, { '甲', '乙', '丙' })

    lt.assertEquals('放入后计数', 3, zone:count())
    lt.assertEquals('顺序与放入一致', '甲,乙,丙', zoneLabels(zone))
    lt.assertEquals('查看第二张', cards[2], zone:peek(2))

    local taken = zone:take(2)
    lt.assertEquals('取出的是第二张', cards[2], taken)
    lt.assertEquals('取出后计数', 2, zone:count())
    lt.assertEquals('剩余顺序', '甲,丙', zoneLabels(zone))
end)

lt.test('牌区：列举返回副本，清空清掉全部', function ()
    local zone = moe.zone.create()
    fill(zone, { '甲', '乙' })

    local snapshot = zone:list()
    snapshot[1] = nil

    lt.assertEquals('修改副本不影响牌区', 2, zone:count())
    lt.assertEquals('再列举仍是原内容', '甲,乙', zoneLabels(zone))

    lt.assertEquals('清空返回被清掉的张数', 2, zone:clear())
    lt.assertEquals('清空后计数', 0, zone:count())
    lt.assertEquals('清空后列举为空', '', zoneLabels(zone))
end)

lt.test('牌区：空区取牌与越界取牌明确失败', function ()
    local zone = moe.zone.create()

    lt.assertError('空区取牌', function () zone:take(1) end)
    lt.assertError('空区查看', function () zone:peek(1) end)

    fill(zone, { '甲' })
    lt.assertError('越界取牌', function () zone:take(2) end)
    lt.assertError('越界查看', function () zone:peek(0) end)

    ---@type any
    local notInteger = 1.5
    lt.assertError('序号非整数', function () zone:take(notInteger) end)

    lt.assertEquals('失败后内容不变', '甲', zoneLabels(zone))
end)

lt.test('牌区：kind 只用来区分子类', function ()
    lt.assertEquals('基类的 kind', 'zone', moe.zone.create().kind)
    lt.assertEquals('有序子类的 kind', 'orderedZone', moe.orderedZone.create().kind)
end)

lt.test('牌区：禁用后不可放入取出，启用后恢复', function ()
    local zone = moe.zone.create()
    fill(zone, { '甲' })

    lt.assertEquals('初始为启用', true, zone:isEnabled())
    lt.assertEquals('禁用生效', true, zone:disable())
    lt.assertEquals('重复禁用无副作用', false, zone:disable())

    lt.assertError('禁用后放入失败', function () zone:put(lt.card('乙')) end)
    lt.assertError('禁用后取出失败', function () zone:take(1) end)
    lt.assertError('禁用后清空失败', function () zone:clear() end)
    lt.assertEquals('禁用期间内容仍可读', '甲', zoneLabels(zone))

    lt.assertEquals('启用生效', true, zone:enable())
    lt.assertEquals('重复启用无副作用', false, zone:enable())

    zone:put(lt.card('乙'))
    lt.assertEquals('启用后恢复放入', '甲,乙', zoneLabels(zone))
end)

lt.test('有序牌区：相同随机源洗出相同顺序', function ()
    lt.assertEquals('同种子同顺序', shuffledLabels(20260919), shuffledLabels(20260919))
    lt.assertNotEquals('异种子异顺序', shuffledLabels(20260919), shuffledLabels(20260920))
    lt.assertNotEquals('洗牌确实改变顺序', table.concat(DECK, ','), shuffledLabels(20260919))
end)

lt.test('有序牌区：依次取顶与洗牌后顺序一致', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(7))

    local expected = zoneLabels(zone)
    local drawn    = {}
    while zone:count() > 0 do
        drawn[#drawn + 1] = tostring(zone:takeTop():getLabel())
    end

    lt.assertEquals('取顶顺序与洗牌后一致', expected, table.concat(drawn, ','))
    lt.assertEquals('取完后计数为 0', 0, zone:count())
    lt.assertError('取空后继续取顶失败', function () zone:takeTop() end)
end)

lt.test('有序牌区：从顶取 n 张，不够就少给', function ()
    local zone = moe.orderedZone.create()
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
    local zone  = moe.orderedZone.create()
    local stock = moe.zone.create()
    fill(stock, { '甲', '乙', '丙' })

    ---@type integer
    local times = 0
    zone:setShortageHandler(function (target)
        times = times + 1
        lt.assertEquals('回调收到的是这个区', zone, target)
        for _, card in ipairs(stock:list()) do
            stock:move(card, zone)
        end
    end)

    local cards = zone:draw(3)

    lt.assertEquals('只调了一次', 1, times)
    lt.assertEquals('取到 3 张', 3, #cards)
    lt.assertEquals('按补进来的顺序取', '甲,乙,丙', labels(cards))
end)

lt.test('有序牌区：回调补不到牌就少给', function ()
    local zone = moe.orderedZone.create()

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
    local zone = moe.orderedZone.create()

    lt.assertEquals('要 3 张拿到 0 张', 0, #zone:draw(3))
end)

lt.test('有序牌区：洗牌必须传入随机源', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)

    ---@type any
    local notRandom = {}

    ---@type any
    local noRandom = nil

    lt.assertError('随机源类型不对', function () zone:shuffle(notRandom) end)
    lt.assertError('没有随机源', function () zone:shuffle(noRandom) end)
    lt.assertEquals('失败后顺序不变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('有序牌区：禁用后不能洗牌', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:disable()

    lt.assertError('禁用后洗牌失败', function () zone:shuffle(moe.random.create(1)) end)
    lt.assertEquals('顺序未变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('牌区：默认对所有人可见，设成暗区后只有持有者看得见', function ()
    local game   = moe.game.create { seats = 2, random = moe.random.create(1) }
    local system = moe.attribute.create()
    local mine   = moe.player.create(game, { attributes = system:createInstance() })
    local other  = moe.player.create(game, { attributes = system:createInstance() })

    local open = moe.zone.create()
    lt.assertEquals('默认对所有人可见', true, open:isVisibleTo(other))

    local hand = mine:getZone('手牌')
    hand:setVisible(false)

    lt.assertEquals('持有者自己看得见', true, hand:isVisibleTo(mine))
    lt.assertEquals('别人看不见', false, hand:isVisibleTo(other))

    local nobody = moe.zone.create()
    nobody:setVisible(false)
    lt.assertEquals('没有归属的暗区：谁都看不见', false, nobody:isVisibleTo(mine))
end)

---@return Game # 换下来的牌要有个地方去（槽位区的弃牌堆）
local function newGame()
    return moe.game.create { seats = 2, random = moe.random.create(1) }
end

lt.test('槽位区：放进空槽、同槽换新时旧牌进弃牌堆', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器', '防具' })
    local slot = assert(game:getZone('弃牌'), '局上有弃牌区')

    lt.assertEquals('kind 只用来区分子类', 'slotZone', zone.kind)
    lt.assertEquals('声明的槽位按顺序', '武器,防具', table.concat(zone.slots, ','))
    lt.assertEquals('空槽读不到', nil, zone:getSlot('武器'))

    local old = lt.card('甲')
    zone:putInto('武器', old)
    lt.assertEquals('放进去就读得到', old, zone:getSlot('武器'))
    lt.assertEquals('牌记着自己在哪个区', zone, old:getZone())
    lt.assertEquals('另一个槽还是空的', nil, zone:getSlot('防具'))

    local new = lt.card('乙')
    zone:putInto('武器', new)
    lt.assertEquals('槽里换成新的', new, zone:getSlot('武器'))
    lt.assertEquals('一个槽始终只有一张（装备区也只有这一张）', 1, zone:count())
    lt.assertEquals('旧的进了弃牌堆', old, slot:list()[1])
    lt.assertEquals('旧的不再属于这个区', slot, old:getZone())
end)

lt.test('槽位区：牌不必先在本区，可以从别的区搬进来', function ()
    local game  = newGame()
    local zone  = moe.slotZone.create(game):setSlots({ '武器' })
    local other = moe.zone.create()
    local card  = lt.card('甲')
    other:put(card)

    zone:putInto('武器', card)

    lt.assertEquals('源区空了', 0, other:count())
    lt.assertEquals('牌进了槽', card, zone:getSlot('武器'))
end)

lt.test('槽位区：牌被别的路径取走后槽位就地失效', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器' })
    local card = lt.card('甲')
    zone:putInto('武器', card)

    zone:take(1)

    lt.assertEquals('槽位读不到那张牌了', nil, zone:getSlot('武器'))

    local again = lt.card('乙')
    zone:putInto('武器', again)
    lt.assertEquals('空出来的槽能重新放', again, zone:getSlot('武器'))
    lt.assertEquals('区里就那一张', 1, zone:count())
    lt.assertEquals('这次没有旧牌要弃（牌早就走了）', 0, assert(game:getZone('弃牌')):count())
end)

lt.test('槽位区：清空后槽位全空', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器', '防具' })
    zone:putInto('武器', lt.card('甲'))
    zone:putInto('防具', lt.card('乙'))

    lt.assertEquals('清空返回张数', 2, zone:clear())

    lt.assertEquals('武器槽空了', nil, zone:getSlot('武器'))
    lt.assertEquals('防具槽空了', nil, zone:getSlot('防具'))
    lt.assertEquals('清空的牌没有自动进弃牌堆（归内容侧）', 0,
        assert(game:getZone('弃牌')):count())
end)

lt.test('槽位区：未声明的槽位名明确失败', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器' })

    lt.assertError('放进去时', function () zone:putInto('防具', lt.card('甲')) end)
    lt.assertError('读的时候', function () zone:getSlot('防具') end)
    lt.assertEquals('失败后什么都没放进去', 0, zone:count())

    local bare = moe.slotZone.create(game)
    lt.assertEquals('不声明就没有槽位', 0, #bare.slots)
    lt.assertError('没有槽位也放不进去', function () bare:putInto('武器', lt.card('甲')) end)
end)

lt.test('槽位区：没记着局时替换不了槽里的牌', function ()
    local zone = moe.slotZone.create(nil):setSlots({ '武器' })
    local card = lt.card('甲')

    zone:putInto('武器', card)
    lt.assertEquals('空槽还是能放', card, zone:getSlot('武器'))
    lt.assertError('要替换就得知道弃牌堆在哪一局', function ()
        zone:putInto('武器', lt.card('乙'))
    end)
end)
