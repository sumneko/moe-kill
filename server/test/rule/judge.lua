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

lt.test('判定：嵌在别的结算里，判定牌在该次判定结束时就走', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local discard = assert(run.game:getZone('弃牌'), '没有弃牌')
    ---@type 判定?
    local judge = nil
    ---@type boolean?
    local flushed = nil

    run.game:on('伤害-前', function ()
        judge = run.game:judge(run.players[2], '测试')
    end)
    run.game:on('伤害-后', function ()
        flushed = judge ~= nil and judge.card ~= nil and judge.card:getZone() == discard
    end)

    run.game:damage(run.players[1], run.players[2], 1)

    lt.assertEquals('伤害结算里起过判定', true, judge ~= nil)
    lt.assertEquals('判定牌在判定结束时就已经进弃牌堆', true, flushed == true)
end)

lt.test('判定：换牌只能在「判定-前」里做，账按换下的顺序记', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local deck    = assert(run.game:getZone('抽牌'), '没有抽牌')
    local first   = deck:peek(1)
    local second  = deck:peek(2)
    local third   = deck:peek(3)
    local earlyErr, afterErr
    earlyErr = lt.assertError('还没开窗口就换牌', function ()
        New '判定' (run.game, run.players[1], '测试'):replace(second)
    end)

    run.game:on('判定-前', function (judge)
        judge:replace(second)
        judge:replace(third)
    end)
    run.game:on('判定-后', function (judge)
        afterErr = lt.assertError('结算后换牌', function ()
            judge:replace(first)
        end)
    end)

    local judge = run.game:judge(run.players[1], '测试')

    lt.assertEquals('种类标识', '判定', judge.kind)
    lt.assertEquals('缘由原样带着', '测试', judge.reason)
    lt.assertEquals('判的是最后换上的那张', third, judge.card)
    lt.assertEquals('换过两次', 2, #judge.replaced)
    lt.assertEquals('先被换下的是第一张', first, judge.replaced[1])
    lt.assertEquals('再被换下的是第二张', second, judge.replaced[2])
    lt.assertEquals('还没开窗口就换不了', true, earlyErr ~= nil)
    lt.assertEquals('结算后换不了', true, afterErr ~= nil)
    lt.assertEquals('不是失败', nil, judge.err)
end)
