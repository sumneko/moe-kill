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
        if options.stopAfter and state.task and state.turns >= options.stopAfter then
            state.task:cancel()
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
---@return integer # 牌表总张数
local function totalCards(game)
    local total = 0
    for _, entry in ipairs(assert(game:getValue('牌表'), '没有牌表')) do
        total = total + entry.count
    end
    return total
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
            run.game:on('回合-开始', function (ctx)
                firstPlayer = firstPlayer or ctx.player
            end)
            run.game:on('阶段-开始', function (ctx)
                marks[#marks+1] = '开始:' .. ctx.phase
            end)
            run.game:on('阶段-结束', function (ctx)
                marks[#marks+1] = '结束:' .. ctx.phase
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
            run.game:on('回合-开始', function (ctx)
                started[#started+1] = ctx.player
            end)
        end,
        answer    = endPhase(),
        stopAfter = 2,
    }

    advance(state, 2)

    lt.assertEquals('第一个回合是主公', state.run.players[1], started[1])
    lt.assertEquals('2 号位阵亡者被跳过，轮到 3 号位', state.run.players[3], started[2])
end)

lt.test('回合：出牌阶段问满上限就结束，不会一直问下去', function ()
    ---@type Zone?
    local hand = nil
    local state = startTurn {
        setup = function (run)
            hand = assert(run.players[1]:getZone('手牌'), '没有手牌区')
            hand:put(run.game:createCard('闪'))     -- 【闪】没声明「获取目标」⇒ 拿它出牌必然失败
        end,
        answer = function (ask)
            local card = assert(ask.to:getZone('手牌'), '被问者没有手牌区'):list()[1]
            return { card = card }                  -- 每次都答同一张（且不给目标）
        end,
        stopAfter = 1,
    }

    state.task:await()

    lt.assertEquals('一个回合正常跑完了（不是卡在这儿）', 1, state.turns)
    lt.assertEquals('那张用不了的牌一次也没用出去（摸 2 + 那张闪）', 3, assert(hand):count())
end)
