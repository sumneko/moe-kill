local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param run Test.RuleSupport
---@param player Player
---@return Zone
local function handOf(run, player)
    return assert(player:getZone('手牌'), '这个玩家没有手牌区')
end

lt.test('抽牌：game:draw 让目标摸到牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local player = run.players[1]
    local deck   = assert(run.game:getZone('抽牌'), '没有抽牌')
    local before = deck:count()

    local draw = run.game:draw(player, 3)

    lt.assertEquals('抽牌少了 3 张', before - 3, deck:count())
    lt.assertEquals('手牌多了 3 张', 3, handOf(run, player):count())
    lt.assertEquals('种类标识', 'draw', draw.kind)
    lt.assertEquals('没失败', nil, draw.err)
end)

lt.test('抽牌：抽牌不够时把弃牌洗回来', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local player  = run.players[1]
    local deck    = assert(run.game:getZone('抽牌'), '没有抽牌')
    local discard = assert(run.game:getZone('弃牌'), '没有弃牌')

    local cards = deck:list()
    for i = 2, #cards do
        deck:move(cards[i], discard)
    end
    lt.assertEquals('抽牌里只剩 1 张', 1, deck:count())

    run.game:draw(player, 3)

    lt.assertEquals('洗回之后摸够了 3 张', 3, handOf(run, player):count())
    lt.assertEquals('弃牌全被洗回抽牌 ⇒ 空了', 0, discard:count())
end)

lt.test('抽牌：牌堆和弃牌都空时能摸多少摸多少，不报错', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local player = run.players[1]
    local deck   = assert(run.game:getZone('抽牌'), '没有抽牌')

    local somewhere = run.game:createZone('别处')
    for _, card in ipairs(deck:list()) do
        deck:move(card, somewhere)
    end

    local draw = run.game:draw(player, 2)

    lt.assertEquals('一张都没摸到', 0, handOf(run, player):count())
    lt.assertEquals('不是失败', nil, draw.err)
end)
