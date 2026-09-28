local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param game Game
---@param name string
---@return Card # 抽牌里第一张叫这个名字的牌
---@return Zone # 它所在的牌区
local function findCard(game, name)
    local deck = assert(game:getZone('抽牌'), '没有抽牌')
    for _, card in ipairs(deck:list()) do
        if card.name == name then
            return card, deck
        end
    end
    error('抽牌里没有「{}」' % { name })
end

---@param run Test.RuleSupport
---@param player Player
---@param name string
---@return Card # 已经摆进该玩家手牌的牌
local function takeCard(run, player, name)
    local card, deck = findCard(run.game, name)
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    deck:move(card, hand)
    return card
end

---@param run Test.RuleSupport
---@param player Player
---@param name string
---@return Card # 已经摆进该玩家判定区的牌
local function toJudgeZone(run, player, name)
    local card, deck = findCard(run.game, name)
    deck:move(card, player:getZone('判定'))
    return card
end

--- 把某个延时锦囊的判定换成指定的牌（判定-前 窗口）
---@param run Test.RuleSupport
---@param name string # 缘由 = 牌名
---@param suit string
---@param point integer
local function decide(run, name, suit, point)
    run.game:on('判定-前', function (judge)
        if judge.reason == name then
            judge:replace(run.game:createCard('测试牌', suit, point))
        end
    end)
end

---@class Test.DelayedFlow
---@field run Test.RuleSupport
---@field task? Task # 启动后才有
---@field turns integer

--- 启动流程：记回合数；给了 stopAfter 就在第几个回合结束时停掉
---@param run Test.RuleSupport
---@param stopAfter? integer
---@return Test.DelayedFlow
local function startFlow(run, stopAfter)
    ---@type Test.DelayedFlow
    local state = { run = run, turns = 0 }
    run.game:on('回合-结束', function ()
        state.turns = state.turns + 1
        if stopAfter and state.turns >= stopAfter then
            moe.await.sleep(0)
            assert(state.task):cancel()
        end
    end)
    state.task = run.game:runFlow()
    return state
end

--- 推进流程：等够 n 个回合（或流程自己先跑完）
---@param state Test.DelayedFlow
---@param turns integer
local function advance(state, turns)
    local task = assert(state.task, '流程还没启动')
    for _ = 1, 500 do
        if state.turns >= turns or task.resolved then
            return
        end
        moe.await.sleep(0)
    end
    error('流程没跑到 {} 个回合（err={}）' % { turns, tostring(task.err) }, 2)
end

---@param run Test.RuleSupport
---@param player Player
---@return string[] # 这个角色收到的阶段开始（按顺序记）
local function watchStarts(run, player)
    ---@type string[]
    local names = {}
    run.game:on('阶段-开始', function (phase)
        if phase.player == player then
            names[#names + 1] = phase.name
        end
    end)
    return names
end

---@param run Test.RuleSupport
---@param player Player
---@return string[] # 这个角色收到的阶段结束（按顺序记）
local function watchEnds(run, player)
    ---@type string[]
    local names = {}
    run.game:on('阶段-结束', function (phase)
        if phase.player == player then
            names[#names + 1] = phase.name
        end
    end)
    return names
end

---@param run Test.RuleSupport
---@return string[] # 收到的判定缘由（按顺序记）
local function watchJudges(run)
    ---@type string[]
    local reasons = {}
    run.game:on('判定-后', function (judge)
        reasons[#reasons + 1] = assert(judge.reason)
    end)
    return reasons
end

--- 判定阶段里用【无懈可击】抵消一张延时锦囊
---@param run Test.RuleSupport
---@param answerer Player
---@param wuxie Card
---@param target Card # 被抵消的那张
local function nullifyAtJudge(run, answerer, wuxie, target)
    run.game:on('卡牌-询问', function (ask)
        if ask.to ~= answerer then
            return
        end
        local parent = ask.parent
        if not (parent and parent.kind == 'cardEffect') then
            return
        end
        ---@cast parent CardEffect
        if parent.card == target then
            moe.await.sleep(0)
            ask:answer { card = wuxie }
        end
    end)
end

lt.test('延时锦囊：用出去就进目标判定区（乐不思蜀给别人 / 闪电给自己）', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local user  = run.players[1]
    local other = run.players[2]

    local lebu = takeCard(run, user, '乐不思蜀')
    run.game:useCard(user, lebu, { other })
    lt.assertEquals('乐不思蜀进了对方的判定区', lebu, other:getZone('判定'):list()[1])
    lt.assertEquals('弃牌堆里没有它', false, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), lebu))

    local bolt = takeCard(run, user, '闪电')
    run.game:useCard(user, bolt, { user })
    lt.assertEquals('闪电进了自己的判定区', bolt, user:getZone('判定'):list()[1])
    lt.assertEquals('手牌里没有它了', false, moe.util.arrayHas(user:getZone('手牌'):list(), bolt))
end)

lt.test('延时锦囊：判定阶段逆序结算（后置入的先判），闪电判不中传给下家', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local lebu = toJudgeZone(run, user, '乐不思蜀')
    local bolt = toJudgeZone(run, user, '闪电')
    local reasons = watchJudges(run)
    decide(run, '闪电', '红桃', 5)
    decide(run, '乐不思蜀', '红桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('后放进去的闪电先判、再判乐不思蜀', '闪电,乐不思蜀', table.concat(reasons, ','))
    lt.assertEquals('乐不思蜀结完进弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), lebu))
    lt.assertEquals('闪电挪到了下家判定区', bolt, run.players[2]:getZone('判定'):list()[1])
    lt.assertEquals('自己的判定区空了', 0, user:getZone('判定'):count())
end)

lt.test('延时锦囊：结算前已经不在判定区里的牌跳过不结算', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local lebu = toJudgeZone(run, user, '乐不思蜀')
    toJudgeZone(run, user, '闪电')
    local reasons = watchJudges(run)
    run.game:on('判定-后', function (judge)
        if judge.reason == '闪电' then
            -- 模拟「在轮到它之前被拿走」
            run.game:moveCard(lebu, '弃牌')
        end
    end)
    decide(run, '闪电', '红桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('闪电之后乐不思蜀没有再判（它已经不在判定区里）', '闪电', table.concat(reasons, ','))
    lt.assertEquals('被拿走的那张不在判定区', false, moe.util.arrayHas(user:getZone('判定'):list(), lebu))
end)

lt.test('乐不思蜀：判红桃不跳过，六个阶段照常', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local lebu = toJudgeZone(run, user, '乐不思蜀')
    local names = watchStarts(run, user)
    decide(run, '乐不思蜀', '红桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('六个阶段都开始过', '准备,判定,摸牌,出牌,弃牌,结束', table.concat(names, ','))
    lt.assertEquals('乐不思蜀结完进弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), lebu))
end)

lt.test('乐不思蜀：判非红桃就跳过出牌阶段（那个阶段的开始 / 结束都不发）', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    toJudgeZone(run, user, '乐不思蜀')
    local starts = watchStarts(run, user)
    local ends   = watchEnds(run, user)
    decide(run, '乐不思蜀', '黑桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('开始事件里没有出牌阶段', '准备,判定,摸牌,弃牌,结束', table.concat(starts, ','))
    lt.assertEquals('结束事件里也没有出牌阶段', '准备,判定,摸牌,弃牌,结束', table.concat(ends, ','))
    lt.assertEquals('摸牌照常', 2, user:getZone('手牌'):count())
end)

lt.test('延时锦囊：判定区里有同名牌时用不出去（乐不思蜀 / 闪电各自）', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local second = run.players[2]
    local third  = run.players[3]
    toJudgeZone(run, second, '乐不思蜀')

    local lebu = takeCard(run, user, '乐不思蜀')
    local ok, reason = run.game:canUse(user, lebu, { second })
    lt.assertEquals('对判定区已有乐不思蜀的人用不了', false, ok)
    lt.assertEquals('理由是「不能以这个角色为目标」', '「标准.乐不思蜀」不能以这个角色为目标', reason)

    local good, _, legal = run.game:canUse(user, lebu, { third })
    lt.assertEquals('对没有同名牌的别人用得了', true, good)
    lt.assertEquals('合法目标里排除了拿着同名的那位', false, moe.util.arrayHas(assert(legal), second))

    toJudgeZone(run, user, '闪电')
    local bolt = takeCard(run, user, '闪电')
    local selfOk = run.game:canUse(user, bolt, { user })
    lt.assertEquals('自己判定区已有闪电也对自己用不了', false, selfOk)
end)

lt.test('闪电：判定黑桃 2~9（含首尾）就受 3 点无来源伤害，牌进弃牌堆', function ()
    for _, point in ipairs { 2, 9 } do
        local run    = support.start { count = 2, packages = { '标准' } }
        local victim = run.players[1]
        local bolt   = toJudgeZone(run, victim, '闪电')
        local before = victim:getAttr('体力')
        ---@type Damage?
        local taken  = nil
        run.game:on('伤害-结束', function (damage)
            taken = damage
        end)
        decide(run, '闪电', '黑桃', point)

        local state = startFlow(run, 1)
        advance(state, 1)

        local damage = assert(taken, ('黑桃{}：没有收到伤害' % { point }))
        lt.assertEquals(('黑桃{}：挨了 3 点' % { point }), before - 3, victim:getAttr('体力'))
        lt.assertEquals(('黑桃{}：伤害来源为空' % { point }), nil, damage.from)
        lt.assertEquals(('黑桃{}：承受者是判定者' % { point }), victim, damage.to)
        lt.assertEquals(('黑桃{}：就是 3 点' % { point }), 3, damage.amount)
        lt.assertEquals(('黑桃{}：闪电进弃牌堆' % { point }), true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), bolt))
    end
end)

lt.test('闪电：判定黑桃 1 不算中，活着传给下家', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local victim = run.players[1]
    local bolt   = toJudgeZone(run, victim, '闪电')
    local before = victim:getAttr('体力')
    decide(run, '闪电', '黑桃', 1)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('没掉血', before, victim:getAttr('体力'))
    lt.assertEquals('闪电挪到了下家判定区', bolt, run.players[2]:getZone('判定'):list()[1])
    lt.assertEquals('没有进弃牌堆', false, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), bolt))
end)

lt.test('闪电：下家判定区已有闪电就继续往下找', function ()
    local run = support.start { count = 3, packages = { '标准' } }
    local first  = run.players[1]
    local second = run.players[2]
    local third  = run.players[3]
    local bolt   = toJudgeZone(run, first, '闪电')
    toJudgeZone(run, second, '闪电')
    decide(run, '闪电', '红桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('跳过已有闪电的下家，落到下下家', bolt, third:getZone('判定'):list()[1])
    lt.assertEquals('下家自己那张还在', 1, second:getZone('判定'):count())
end)

lt.test('闪电：别人都拿着闪电时进弃牌堆', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local first  = run.players[1]
    local second = run.players[2]
    local bolt   = toJudgeZone(run, first, '闪电')
    toJudgeZone(run, second, '闪电')
    decide(run, '闪电', '红桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('自己的判定区空了', 0, first:getZone('判定'):count())
    lt.assertEquals('进了弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), bolt))
end)

lt.test('闪电：打死回合角色就结束这个回合，后面的阶段不再进行', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local victim = run.players[1]
    victim:setAttr('体力', 3)
    toJudgeZone(run, victim, '乐不思蜀')
    local bolt    = toJudgeZone(run, victim, '闪电')
    local starts  = watchStarts(run, victim)
    local reasons = watchJudges(run)
    decide(run, '闪电', '黑桃', 5)

    local state = startFlow(run)
    advance(state, 1)
    moe.await.sleep(0)
    moe.await.sleep(0)

    lt.assertEquals('回合角色阵亡', false, victim:isAlive())
    lt.assertEquals('只走到判定阶段', '准备,判定', table.concat(starts, ','))
    lt.assertEquals('闪电之后没再判乐不思蜀', '闪电', table.concat(reasons, ','))
    lt.assertEquals('闪电进了弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), bolt))
    lt.assertEquals('阵亡清算不在本批（判定区的乐不思蜀还留着）', 1, victim:getZone('判定'):count())
    lt.assertEquals('流程到这里就结束了（没有下一个回合）', true, assert(state.task).resolved)
end)

lt.test('延时锦囊：判定阶段被无懈可击抵消 ⇒ 不判定、进弃牌堆', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local victim  = run.players[1]
    local lebu    = toJudgeZone(run, victim, '乐不思蜀')
    local wuxie   = takeCard(run, run.players[2], '无懈可击')
    local reasons = watchJudges(run)
    local starts  = watchStarts(run, victim)
    nullifyAtJudge(run, run.players[2], wuxie, lebu)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('没有进行判定', '', table.concat(reasons, ','))
    lt.assertEquals('乐不思蜀进了弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), lebu))
    lt.assertEquals('无懈也进了弃牌堆', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), wuxie))
    lt.assertEquals('出牌阶段没被跳过', '准备,判定,摸牌,出牌,弃牌,结束', table.concat(starts, ','))
end)

lt.test('延时锦囊：判定区逐张结算，第一张被抵消不影响第二张', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local victim  = run.players[1]
    toJudgeZone(run, victim, '乐不思蜀')
    local bolt    = toJudgeZone(run, victim, '闪电')
    local wuxie   = takeCard(run, run.players[2], '无懈可击')
    local reasons = watchJudges(run)
    local starts  = watchStarts(run, victim)
    nullifyAtJudge(run, run.players[2], wuxie, bolt)
    decide(run, '乐不思蜀', '黑桃', 5)

    local state = startFlow(run, 1)
    advance(state, 1)

    lt.assertEquals('只有乐不思蜀判了', '乐不思蜀', table.concat(reasons, ','))
    lt.assertEquals('闪电被抵消后进了弃牌堆（没有传递）', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), bolt))
    lt.assertEquals('别人没拿到闪电', 0, run.players[2]:getZone('判定'):count())
    lt.assertEquals('乐不思蜀照常跳过出牌阶段', '准备,判定,摸牌,弃牌,结束', table.concat(starts, ','))
end)

lt.test('延时锦囊：使用期不产生无懈询问（判定前才有窗口）', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local user  = run.players[1]
    local other = run.players[2]
    local lebu  = takeCard(run, user, '乐不思蜀')
    local asked = false
    run.game:on('卡牌-询问', function (ask)
        if ask.to == other and ask.parent?.kind == 'cardEffect' then
            asked = true
        end
    end)

    run.game:useCard(user, lebu, { other })

    lt.assertEquals('没人被问要不要用无懈', false, asked)
    lt.assertEquals('乐不思蜀照常置入判定区', lebu, other:getZone('判定'):list()[1])
end)
