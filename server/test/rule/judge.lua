local lt      = require 'test.ltest'
local support = require 'test.rule.support'

lt.test('判定：判定牌来自抽牌堆顶，结完进弃牌堆', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local deck    = assert(run.game:getZone('抽牌'), '没有抽牌')
    local discard = assert(run.game:getZone('弃牌'), '没有弃牌')
    local top     = deck:peek(1)

    local judge = run.game:judge(run.players[1], '测试')

    lt.assertEquals('判定牌就是抽牌堆顶那张', top, judge.card)
    lt.assertEquals('缘由原样带着', '测试', judge.reason)
    lt.assertEquals('判定牌进了弃牌堆', discard, judge.card:getZone())
    lt.assertEquals('没换过牌', 0, #judge.replaced)
    lt.assertEquals('不是失败', nil, judge.err)
end)

lt.test('判定：抽牌堆空了会把弃牌洗回来', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local deck    = assert(run.game:getZone('抽牌'), '没有抽牌')
    local discard = assert(run.game:getZone('弃牌'), '没有弃牌')

    for _, card in ipairs(deck:list()) do
        deck:move(card, discard)
    end
    lt.assertEquals('抽牌堆空了', 0, deck:count())

    local judge = run.game:judge(run.players[2])

    lt.assertEquals('翻出了牌', false, judge.card == nil)
    lt.assertEquals('翻出的那张又回到弃牌堆（其余洗回抽牌堆）', 1, discard:count())
end)

lt.test('判定：改判换上的牌与旧判定牌都进弃牌堆', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local deck    = assert(run.game:getZone('抽牌'), '没有抽牌')
    local discard = assert(run.game:getZone('弃牌'), '没有弃牌')
    local before  = discard:count()
    local old     = deck:peek(1)
    local new     = deck:peek(2)

    run.game:on('判定-前', function (judge)
        judge:replace(new)
    end)

    local judge = run.game:judge(run.players[1])

    lt.assertEquals('结果是换上的那张', new, judge.card)
    lt.assertEquals('旧的那张记在账上', old, judge.replaced[1])
    lt.assertEquals('两张都进了弃牌堆', before + 2, discard:count())
    lt.assertEquals('换上那张的归属是弃牌堆', discard, new:getZone())
    lt.assertEquals('旧那张的归属也是弃牌堆', discard, old:getZone())
end)
