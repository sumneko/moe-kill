local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'card-def-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param source string # 探针包里的定义
---@return Game
---@return Player # 1 号位
local function newGame(source)
    write('探针/牌.lua', source)
    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
    desk:sit(1, player)
    player:setAttr('体力', 4)
    return game, player
end

---@param game Game
---@param name string
---@return string # 分类列表拼成一行
local function kindsOf(game, name)
    return table.concat(assert(game:getCard(name)):getKinds(), ',')
end

lt.test('定义：分类一次给一张列表，重复调以后写的为准，取到的是快照', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind { '锦囊', '延时锦囊', '锦囊' }
Card '乙'
    : kind '基本'
    : kind '装备'
]])

    lt.assertEquals('按列表顺序，重名只算一次', '锦囊,延时锦囊', kindsOf(game, '甲'))
    lt.assertEquals('重复调以后写的为准', '装备', kindsOf(game, '乙'))

    local def = assert(game:getCard('甲'))
    lt.assertEquals('isKind 正面', true, def:isKind('延时锦囊'))
    lt.assertEquals('isKind 反面', false, def:isKind('基本'))

    local snapshot = def:getKinds()
    snapshot[1] = '改过'
    lt.assertEquals('拿到的列表改不动定义', '锦囊,延时锦囊', kindsOf(game, '甲'))
end)

lt.test('定义：牌区声明与读、重复写后者覆盖、不声明就是空', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : zone '手牌'
    : zone '装备'
Card '乙'
]])

    lt.assertEquals('重复写以后写的为准', '装备', assert(game:getCard('甲')):getZone())
    lt.assertEquals('不声明就是空', nil, assert(game:getCard('乙')):getZone())
end)

lt.test('定义：extends 抄分类、牌区与限额，基类的钩子跑在前面', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '基'
    : kind '基本'
    : zone '手牌'
    : limit('出牌', 2)
    : on('获取目标', function (target)
        target.user:setTag('顺序', (target.user:getTag('顺序') or '') .. '基')
        return game.desk.players
    end)
Card '子'
    : extends '基'
    : limit('出牌', 5)
    : on('获取目标', function (target)
        target.user:setTag('顺序', (target.user:getTag('顺序') or '') .. '子')
        return game.desk.players
    end)
]])

    local def = assert(game:getCard('子'))

    lt.assertEquals('抄来了分类', true, def:isKind('基本'))
    lt.assertEquals('抄来了牌区', '手牌', def:getZone())
    lt.assertEquals('自己写的限额覆盖基类的', 5, def:getLimit('出牌'))

    local handlers = def:getHandlers('获取目标')
    lt.assertEquals('两个钩子都在', 2, #handlers)
    local card = lt.card('子')
    for _, handler in ipairs(handlers) do
        handler({ user = player, card = card })
    end
    lt.assertEquals('基类的钩子先跑', '基子', player:getTag('顺序'))
end)

lt.test('定义：extends 是快照，抄完两边各管各的', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind '基本'
    : zone '手牌'
    : limit('出牌', 2)
Card '子'
    : extends '基'
]])

    local base = assert(game:getCard('基'))
    local def  = assert(game:getCard('子'))

    def:kind('测试')
    lt.assertEquals('改子定义不影响基类', false, base:isKind('测试'))

    base:kind('装备')
    base:zone('装备')
    base:limit('出牌', 9)

    lt.assertEquals('改基类的分类不影响已抄过的子定义', false, def:isKind('装备'))
    lt.assertEquals('改基类的牌区不影响已抄过的子定义', '手牌', def:getZone())
    lt.assertEquals('改基类的限额不影响已抄过的子定义', 2, def:getLimit('出牌'))
    lt.assertEquals('基类自己变了', '装备', base:getZone())
end)

lt.test('定义：多次 extends 依次合并', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind '基本'
    : zone '手牌'
Card '乙'
    : kind '锦囊'
    : zone '装备'
Card '子'
    : extends '甲'
    : extends '乙'
]])

    local def = assert(game:getCard('子'))

    lt.assertEquals('分类以后一次为准（覆盖）', '锦囊', kindsOf(game, '子'))
    lt.assertEquals('牌区以后写的为准', '装备', def:getZone())
end)

lt.test('定义：extends 拄分类是覆盖，基类没分类就不动', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind '基本'
Card '素'
    : zone '手牌'
Card '子'
    : kind '装备'
    : extends '基'
Card '丙'
    : extends '基'
    : kind '锦囊'
Card '丁'
    : kind '装备'
    : extends '素'
]])

    lt.assertEquals('基类的分类覆盖自己写的', '基本', kindsOf(game, '子'))
    lt.assertEquals('extends 之后写的覆盖拄来的', '锦囊', kindsOf(game, '丙'))
    lt.assertEquals('基类没分类就不动自己的', '装备', kindsOf(game, '丁'))
end)

lt.test('定义：extends 支持限定名', function ()
    local guard <close> = useProbe()
    write('另一个/牌.lua', [[
Card '甲'
    : kind '基本'
]])
    write('探针/牌.lua', [[
Card '子'
    : extends '另一个.甲'
]])
    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '另一个', '探针' },
    }
    local desk = game.desk

    lt.assertEquals('按限定名取到基类', true, assert(game:getCard('子')):isKind('基本'))
end)

lt.test('定义：找不到基类就报错', function ()
    local guard <close> = useProbe()

    local err = lt.assertError('继承不存在的定义', function ()
        newGame([[
Card '子'
    : extends '没有这个'
]])
    end) or ''

    lt.assertEquals('错误里点名那个名字', true, err:find('没有这个', 1, true) ~= nil)
end)

lt.test('定义：addKind 只往里加，重复的与已有分类不动', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind '装备'
    : addKind '武器'
    : addKind { '装备', '武器', '坐骑' }
]])

    lt.assertEquals('已有的保留、新加的接在后面', '装备,武器,坐骑', kindsOf(game, '甲'))
    lt.assertEquals('加进来的也认', true, assert(game:getCard('甲')):isKind('坐骑'))
end)

lt.test('定义：addKind 接在 extends 之后用，基类分类不会丢', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind { '装备', '坐骑' }
Card '子'
    : extends '基'
    : addKind '进攻马'
]])

    lt.assertEquals('抄来的在后面加的仍留着', '装备,坐骑,进攻马', kindsOf(game, '子'))
end)

lt.test('定义：牌进玩家的牌区就发「进入区域」，进槽位时带上槽位名', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '甲'
    : on('进入区域', function (card, zone, slot)
        local owner = assert(zone.owner, '发钩子的时候应该读得到归属者')
        owner:setTag('记录', (owner:getTag('记录') or '')
            .. card.name .. '@' .. tostring(slot) .. ';')
    end)
]])

    local card = game:createCard('甲')
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    hand:put(card)
    lt.assertEquals('放手牌里发一次，普通区没有槽位名', '甲@nil;', player:getTag('记录'))

    local equipZone = assert(player:getZone('装备'), '没有装备区')
    equipZone:setSlots({ '武器' })
    hand:move(card, equipZone)
    lt.assertEquals('移进装备区还没占槽，槽位名仍是空', '甲@nil;甲@nil;', player:getTag('记录'))

    equipZone:putInto('武器', card)
    lt.assertEquals('占上槽位后再发一次，这次给得出槽位名', '甲@nil;甲@nil;甲@武器;',
        player:getTag('记录'))
end)

lt.test('定义：公共区也发「进入区域」，没定义的牌不发', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '甲'
    : on('进入区域', function (card, zone, slot)
        local seat = zone.game.desk.seats[1]
        seat:setTag('记录', (seat:getTag('记录') or '')
            .. tostring(zone.owner ~= nil) .. '/' .. tostring(slot) .. ';')
    end)
]])

    local discard = assert(game:getZone('弃牌'), '没有弃牌区')
    discard:put(game:createCard('甲'))
    lt.assertEquals('公共区也发，只是没有归属者', 'false/nil;', player:getTag('记录'))

    discard:put(game:createCard('没有定义'))
    lt.assertEquals('牌在局里但没有定义，不发', 'false/nil;', player:getTag('记录'))

    local loose = lt.zone()
    loose:put(game:createCard('甲'))
    lt.assertEquals('别的局里没有这张牌的定义，不发', 'false/nil;', player:getTag('记录'))
end)
