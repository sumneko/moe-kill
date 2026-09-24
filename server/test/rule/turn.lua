local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@class Test.TurnRun
---@field run Test.RuleSupport
---@field task? Task # 启动后才有（登记与启动之间有个空档）
---@field turns integer

---@class Test.TurnOptions
---@field count? integer
---@field seed? integer
---@field answers? Card[] # 「卡牌-询问」的脚本（【闪】之类）
---@field answer fun(ask: AskCard, run: Test.RuleSupport): AskCard.Answer? # 出牌阶段的答复（不给牌就结束出牌阶段）
---@field discard? fun(ask: Ask, run: Test.RuleSupport): any # 弃牌阶段的答复（省略 = 一律不答）
---@field stopAfter? integer # 跑够几个回合就停掉流程
---@field setup? fun(run: Test.RuleSupport) # 流程跑起来之前的准备

--- 跑起一局：控制器每次询问都先让出一次再答复（同步答复会让流程不进事件循环，务必保持这个形状）
---@param options Test.TurnOptions
---@return Test.TurnRun
local function startTurn(options)
    local run = support.start {
        packages = { '身份场', '标准' },
        count    = options.count or 4,
        seed     = options.seed or 1,
        answers  = options.answers,
    }

    if options.setup then
        options.setup(run)
    end

    ---@type Test.TurnRun
    local state = { run = run, turns = 0 }

    run.game:on('回合-结束', function ()
        state.turns = state.turns + 1
        if options.stopAfter and state.turns >= options.stopAfter then
            moe.await.sleep(0)
            assert(state.task):cancel()
        end
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.reason ~= '出牌' then
            return
        end
        moe.await.sleep(0)
        ask:answer(options.answer(ask, run))
    end)
    run.game:on('决策-询问', function (ask)
        ---@cast ask Ask
        if not options.discard then
            return
        end
        moe.await.sleep(0)
        ask:answer(options.discard(ask, run))
    end)

    state.task = run.game:runFlow()
    return state
end

---@param state Test.TurnRun
---@param turns integer
local function advance(state, turns)
    for _ = 1, 500 do
        if state.turns >= turns then
            return
        end
        moe.await.sleep(0)
    end
    error('流程没跑到 {} 个回合（err={}）' % { turns, tostring(state.task and state.task.err) }, 2)
end

---@param game Game
---@return integer # 牌表总张数（逐张表：数表长）
local function totalCards(game)
    return #assert(game:getValue('牌表'), '没有牌表')
end

--- 一律「结束出牌阶段」的答复
---@return fun(ask: AskCard, run: Test.RuleSupport): AskCard.Answer?
local function endPhase()
    return function ()
        return nil
    end
end

lt.test('回合：首回合从主公开始，六个阶段依次走完', function ()
    local marks = {}
    ---@type Player?
    local firstPlayer = nil

    local state = startTurn {
        setup = function (run)
            run.game:on('回合-开始', function (turn)
                firstPlayer = firstPlayer or turn.player
            end)
            run.game:on('阶段-开始', function (phase)
                marks[#marks+1] = '开始:' .. phase.name
            end)
            run.game:on('阶段-结束', function (phase)
                marks[#marks+1] = '结束:' .. phase.name
            end)
        end,
        answer    = endPhase(),
        stopAfter = 1,
    }

    advance(state, 1)

    lt.assertEquals('首回合是 1 号位（主公）', state.run.players[1], firstPlayer)
    lt.assertEquals('一个回合里六个阶段各开始、各结束', 12, #marks)
    local expect = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }
    for i, phase in ipairs(expect) do
        lt.assertEquals('第 {} 个阶段开始的是「{}」' % { i, phase }, '开始:' .. phase, marks[i * 2 - 1])
        lt.assertEquals('第 {} 个阶段结束的是「{}」' % { i, phase }, '结束:' .. phase, marks[i * 2])
    end
    lt.assertEquals('停掉之后没有第二个回合', 1, state.turns)
end)

lt.test('回合：回合结束时就把上一个回合角色记下来（顺序锚点）', function ()
    ---@type Player?
    local anchor = nil
    local state = startTurn {
        setup = function (run)
            run.game:on('回合-结束', function ()
                anchor = run.game.lastTurnPlayer
            end)
        end,
        answer    = endPhase(),
        stopAfter = 1,
    }

    advance(state, 1)

    lt.assertEquals('锚点是刚结束回合的那个角色', state.run.players[1], anchor)
end)

lt.test('回合：摸牌阶段摸 2 张', function ()
    local before = 0
    local state = startTurn {
        setup = function (run)
            before = assert(run.game:getZone('抽牌'), '没有抽牌区'):count()
        end,
        stopAfter = 1,
        answer    = endPhase(),
    }
    local game = state.run.game
    local lord = state.run.players[1]
    local deck = assert(game:getZone('抽牌'))

    advance(state, 1)

    lt.assertEquals('手牌比开局多了 2 张', 2, lord:getZone('手牌'):count())
    lt.assertEquals('抽牌少 2 张', before - 2, deck:count())
end)

lt.test('回合：抽牌抽空时把弃牌洗回来', function ()
    local state = startTurn {
        setup = function (run)
            local deck    = assert(run.game:getZone('抽牌'), '没有抽牌区')
            local discard = assert(run.game:getZone('弃牌'), '没有弃牌区')
            local rest    = deck:list()
            rest[#rest]   = nil
            run.game:moveCard(rest, '弃牌')
            lt.assertEquals('抽牌只剩 1 张', 1, deck:count())
            lt.assertEquals('其余都在弃牌里', 101, discard:count())
        end,
        stopAfter = 1,
        answer    = endPhase(),
    }
    local game    = state.run.game
    local deck    = assert(game:getZone('抽牌'))
    local discard = assert(game:getZone('弃牌'))

    advance(state, 1)

    lt.assertEquals('摸到 2 张（含洗回来的一张）', 2, state.run.players[1]:getZone('手牌'):count())
    lt.assertEquals('弃牌清空（都洗回去了）', 0, discard:count())
    lt.assertEquals('总数没变', totalCards(game), deck:count() + 2)
end)

lt.test('回合：出牌阶段用一张杀并结算', function ()
    ---@type Card?
    local slash = nil
    local state = startTurn {
        setup = function (run)
            slash = run.game:createCard('杀')
            run.players[1]:getZone('手牌'):put(slash)
        end,
        answer = function (ask, run)
            if ask.reason ~= '出牌' or not slash then
                return nil
            end
            local card = slash
            slash = nil
            return { card = card, targets = { run.players[2] } }
        end,
        stopAfter = 1,
    }
    local run    = state.run
    local game   = run.game
    local lord   = run.players[1]
    local victim = run.players[2]

    advance(state, 1)

    lt.assertEquals('目标掉 1 点体力', 4, victim:getAttr('体力'))
    lt.assertEquals('杀进了弃牌', 1, game:getZone('弃牌'):count())
    lt.assertEquals('手上少了一张（摸 2 出 1 ⇒ 2 张）', 2, lord:getZone('手牌'):count())
end)

lt.test('回合：弃牌阶段弃到体力值', function ()
    local state = startTurn {
        setup = function (run)
            local hand = assert(run.players[1]:getZone('手牌'), '没有手牌区')
            for _ = 1, 6 do
                hand:put(run.game:createCard('闪'))
            end
        end,
        answer  = endPhase(),
        discard = function (ask)
            local hand = assert(ask.to:getZone('手牌'), '被问者没有手牌区'):list()
            ---@type Card[]
            local cards = {}
            for i = 1, ask.question.count do
                cards[i] = hand[i]
            end
            return { cards = cards }
        end,
        stopAfter = 1,
    }    local run  = state.run
    local game = run.game
    local lord = run.players[1]
    local hand = assert(lord:getZone('手牌'), '没有手牌区')

    advance(state, 1)

    lt.assertEquals('弃到体力值', lord:getAttr('体力'), hand:count())
    lt.assertEquals('弃掉的牌进了弃牌', 2, game:getZone('弃牌'):count())
end)

lt.test('回合：阵亡的角色不再得到回合', function ()
    local started = {}
    local state = startTurn {
        setup = function (run)
            run.players[2]:setAlive(false)
            run.game:on('回合-开始', function (turn)
                started[#started+1] = turn.player
            end)
        end,
        answer    = endPhase(),
        stopAfter = 2,
    }

    advance(state, 2)

    lt.assertEquals('第一个回合是主公', state.run.players[1], started[1])
    lt.assertEquals('2 号位阵亡者被跳过，轮到 3 号位', state.run.players[3], started[2])
end)

lt.test('回合：出牌阶段的选项只含能用的牌，用完【杀】就不再问', function ()
    ---@type string[] # 每次询问时选项里的牌名
    local offered = {}
    local state = startTurn {
        setup = function (run)
            local hand = assert(run.players[1]:getZone('手牌'), '没有手牌区')
            for _ = 1, 3 do
                hand:put(run.game:createCard('杀'))
            end
            -- 【闪】没声明「获取目标」⇒ 用不了
            hand:put(run.game:createCard('闪'))
            run.game:on('卡牌-询问', function (ask)
                if ask.reason ~= '出牌' then
                    return
                end
                ---@type string[]
                local names = {}
                for _, option in ipairs(assert(ask.options)) do
                    names[#names + 1] = assert(option.card.name)
                end
                offered[#offered + 1] = table.concat(names, ',')
            end)
        end,
        answer    = support.pickFirst,
        stopAfter = 1,
    }

    state.task:await()

    lt.assertEquals('问了两次（第二次选项已空，答复方就此收手）', 2, #offered)
    lt.assertEquals('第一次的选项里没有用不了的【闪】', false, offered[1]:find('闪', 1, true) ~= nil)
    lt.assertEquals('第一次的选项里是【杀】', true, offered[1]:find('^杀', 1) ~= nil)
    lt.assertEquals('用完一张【杀】之后第二次的选项空了', '', offered[2])

    local lost = 0
    for _, player in ipairs(state.run.desk.alivePlayers) do
        lost = lost + (player:getAttr('体力上限') - player:getAttr('体力'))
    end
    lt.assertEquals('一共掉 1 点血（一个选项里的目标被打中）', 1, lost)
    lt.assertEquals('用掉的那张进了弃牌', 1, assert(state.run.game:getZone('弃牌')):count())
end)

lt.test('回合：答复不在选项里 ⇒ 拒收，阶段就此结束', function ()
    ---@type Card?
    local jink = nil
    ---@type Zone?
    local hand = nil
    local state = startTurn {
        setup = function (run)
            hand = assert(run.players[1]:getZone('手牌'), '没有手牌区')
            jink = run.game:createCard('闪')
            hand:put(jink)
        end,
        answer = function ()
            -- 乱答一张不在选项里的
            return { card = assert(jink) }
        end,
        stopAfter = 1,
    }

    state.task:await()

    lt.assertEquals('回合照常跑完', 1, state.turns)
    lt.assertEquals('乱答的那张没被用出去（摸 2 + 那张闪）', 3, assert(hand):count())
    lt.assertEquals('弃牌还是空的', 0, assert(state.run.game:getZone('弃牌')):count())
end)

lt.test('回合：【杀】每出牌阶段限一次，阶段外不受限', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local hand   = assert(user:getZone('手牌'), '没有手牌区')
    local first  = run.game:createCard('杀')
    local second = run.game:createCard('杀')
    hand:put(first)
    hand:put(second)

    do
        local _ <close> = run.game:enterPhase(user, '出牌')

        lt.assertEquals('阶段里第一张能用', true, (run.game:canUse(user, first, target)))
        run.game:useCard(user, first, { target })

        local ok, reason = run.game:canUse(user, second, target)
        lt.assertEquals('用过一张之后第二张就用不了了', false, ok)
        lt.assertEquals('原因是「本阶段已经用过」', '本阶段已经用过「杀」了', reason)
        lt.assertEquals('用过的那张记在阶段上', 1, assert(run.game.phase):getUseCount('杀'))
    end

    lt.assertEquals('阶段结束就不受限了', true, (run.game:canUse(user, second, target)))
end)

lt.test('回合：【杀】的两种放宽度各走阶段实例的接口', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local hand   = assert(user:getZone('手牌'), '没有手牌区')
    ---@type Card[]
    local cards = {}
    for i = 1, 4 do
        cards[i] = run.game:createCard('杀')
        hand:put(cards[i])
    end

    local phase <close> = run.game:enterPhase(user, '出牌')

    run.game:useCard(user, cards[1], { target })
    lt.assertEquals('用满一张就用不了了', false, (run.game:canUse(user, cards[2], target)))

    phase:addUseCount('杀', -1)
    lt.assertEquals('退回一次就又能用了（此杀不计入次数）', true, (run.game:canUse(user, cards[2], target)))

    run.game:useCard(user, cards[2], { target })
    lt.assertEquals('再满额又用不了了', false, (run.game:canUse(user, cards[3], target)))

    phase:addLimit('杀', 1)
    lt.assertEquals('上限加 1 就又能用了（可以多用一次）', true, (run.game:canUse(user, cards[3], target)))

    run.game:useCard(user, cards[3], { target })
    lt.assertEquals('加过的额度也会用光', false, (run.game:canUse(user, cards[4], target)))

    phase:addLimit('杀', 1000)
    lt.assertEquals('加 1000 就是事实上不限次数', true, (run.game:canUse(user, cards[4], target)))
end)

lt.test('回合：别人的回合里用【杀】不计数也不受限', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local hand   = assert(user:getZone('手牌'), '没有手牌区')
    local card   = run.game:createCard('杀')
    hand:put(card)

    local phase <close> = run.game:enterPhase(target, '出牌')   -- 阶段是 2 号位的
    phase:addUseCount('杀', 5)

    lt.assertEquals('别人的阶段里不受次数限制', true, (run.game:canUse(user, card, target)))

    run.game:useCard(user, card, { target })

    lt.assertEquals('也不记在别人的阶段上', 5, phase:getUseCount('杀'))
end)
