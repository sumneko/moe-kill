local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'overlay-probe'

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

---@param player Moe.Player
---@return Moe.Attributes
local function attributes(player)
    return player:getAttributes()
end

---@param rule Moe.Rule
---@return integer # 当前牌表的总张数
local function totalCards(rule)
    local cardTable = assert(rule:getValue('牌表'), '没有牌表')
    local total = 0
    for _, entry in ipairs(cardTable) do
        total = total + entry.count
    end
    return total
end

lt.test('基础：规则数值后者覆盖前者', function ()
    local probe <close> = useProbe()
    write('覆盖/配置.lua', 'rule:setValues { 默认体力 = 6 }')

    local rule = moe.rule.create {}
    lt.assertEquals('默认体力来自基础包（它默认加载，不需要写进清单）', 5, rule:getValue('默认体力'))

    rule:setRoots { './package/*', probeDir:string() .. '/*' }
    rule:load { '覆盖' }

    lt.assertEquals('后加载的包覆盖了先前的值', 6, rule:getValue('默认体力'))
end)

lt.test('基础：清空重载后不保留', function ()
    local rule = moe.rule.create { packages = { '标准' } }
    lt.assertEquals('标准包提供了牌表', true, rule:getValue('牌表') ~= nil)
    lt.assertEquals('默认包的值也在', 5, rule:getValue('默认体力'))

    rule:load { '身份场' }

    lt.assertEquals('上一轮非默认包的值被清空', nil, rule:getValue('牌表'))
    lt.assertEquals('默认包总会重新加载，所以值还在', 5, rule:getValue('默认体力'))
end)

lt.test('基础：未设置的名字读到不存在', function ()
    local rule = moe.rule.create {}

    lt.assertEquals('读到不存在', nil, rule:getValue('根本没有这个名字'))

    local snapshot = rule:getValues()
    lt.assertEquals('取全部数值里能看到已设置的', 5, snapshot['默认体力'])

    rule:setValue('临时', 1)
    lt.assertEquals('快照不跟随后续修改', nil, snapshot['临时'])
    lt.assertEquals('但规则数值里已经有了', 1, rule:getValue('临时'))
end)

lt.test('基础：体力初值等于上限', function ()
    local game = support.start { packages = { '身份场', '标准' }, count = 4 }

    for i = 1, 4 do
        lt.assertEquals('第 {} 个玩家的体力等于上限' % { i }, attributes(game.players[i]):get('体力上限'), attributes(game.players[i]):get('体力'))
    end
end)

lt.test('基础：体力上限跟着覆盖后的规则数值', function ()
    local probe <close> = useProbe()
    write('我的配置/配置.lua', 'rule:setValue("默认体力", 3)')

    local game = support.start {
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '我的配置', '身份场', '标准' },
        count    = 4,
    }

    lt.assertEquals('用了覆盖后的上限', 3, attributes(game.players[2]):get('体力上限'))
    lt.assertEquals('体力也跟着走', 3, attributes(game.players[2]):get('体力'))
end)

lt.test('基础：按牌表建出牌堆', function ()
    local game = support.start { packages = { '身份场', '标准' }, count = 4 }

    local deck = assert(game.room:getZone('抽牌堆'), '没有建出抽牌堆')
    lt.assertEquals('张数等于牌表总数', totalCards(game.rule), deck:count())
    lt.assertEquals('每张牌都带牌名标签', '杀', deck:list()[1]:getLabel())
end)

lt.test('基础：洗牌可复现', function ()
    ---@param game Test.RuleSupport
    ---@return string[] # 抽牌堆上的牌名序列
    local function deckLabels(game)
        local deck = assert(game.room:getZone('抽牌堆'), '没有抽牌堆')
        ---@type string[]
        local result = {}
        for i, card in ipairs(deck:list()) do
            result[i] = card:getLabel()
        end
        return result
    end

    local first  = deckLabels(support.start { packages = { '身份场', '标准' }, count = 4, seed = 20260919 })
    local second = deckLabels(support.start { packages = { '身份场', '标准' }, count = 4, seed = 20260919 })

    lt.assertEquals('两次张数一致', #first, #second)
    lt.assertEquals('同一 seed 洗出的顺序一致', table.concat(first, ','), table.concat(second, ','))
end)

lt.test('基础：牌堆里各种牌的张数与牌表一致', function ()
    local game = support.start { packages = { '身份场', '标准' }, count = 4 }

    ---@type table<string, integer>
    local counts = {}
    for _, card in ipairs(assert(game.room:getZone('抽牌堆')):list()) do
        local label = card:getLabel()
        counts[label] = (counts[label] or 0) + 1
    end

    lt.assertEquals('杀 30 张', 30, counts['杀'])
    lt.assertEquals('闪 15 张', 15, counts['闪'])
    lt.assertEquals('桃 8 张', 8, counts['桃'])
    lt.assertEquals('无懈可击 4 张', 4, counts['无懈可击'])
    lt.assertEquals('万箭齐发 1 张', 1, counts['万箭齐发'])
    lt.assertEquals('借刀杀人 2 张', 2, counts['借刀杀人'])
end)

lt.test('基础：没有牌表时不建牌堆', function ()
    local game = support.start { count = 4 }

    lt.assertEquals('没有牌表就不建出抽牌堆（回调报错被时机机制记录）', nil, game.room:getZone('抽牌堆'))
end)

lt.test('基础：体力可以降到负数，写值会被钳到上限', function ()
    local game   = support.start { packages = { '身份场', '标准' }, count = 4 }
    local player = game.players[2]

    lt.assertEquals('开局体力等于上限', 5, player:getAttr('体力'))

    player:setAttr('体力', 99)
    lt.assertEquals('超过上限被钳到上限', 5, player:getAttr('体力'))

    player:setAttr('体力', -2)
    lt.assertEquals('体力可以为负（濒死要用）', -2, player:getAttr('体力'))

    player:addAttr('体力上限', 1)
    lt.assertEquals('抬上限不动体力', -2, player:getAttr('体力'))
end)

lt.test('基础：属性系统由规则实例持有，随清空重载重建', function ()
    local rule = moe.rule.create { packages = { '身份场', '标准' } }

    local before = rule:getAttributeSystem()
    lt.assertEquals('包已经定义过属性', true, before ~= nil)

    rule:load { '身份场', '标准' }

    lt.assertEquals('重载后换了一个属性系统', false, rule:getAttributeSystem() == before)
end)
