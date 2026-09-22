local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'game-over-probe'

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

---@param items string[]
---@return Game
local function newProbeGame(items)
    return moe.game.create {
        desk     = moe.desk.create(2),
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = items,
    }
end

--- 起一个 4 人局，并把身份改写成固定的 1 主公 / 2 忠臣 / 3 反贼 / 4 内奸（身份卡本来是随机发的）
---@return Test.RuleSupport
local function startGame()
    local run = support.start { count = 4, packages = { '身份场', '标准' } }
    run.players[1]:setTag('身份', '主公')
    run.players[2]:setTag('身份', '忠臣')
    run.players[3]:setTag('身份', '反贼')
    run.players[4]:setTag('身份', '内奸')
    return run
end

---@param run Test.RuleSupport
---@param player Player
local function kill(run, player)
    run.game:damage(run.players[1], player, 10)
end

lt.test('胜负：反贼死了但内奸还在，游戏继续', function ()
    local run = startGame()

    kill(run, run.players[3])

    lt.assertEquals('反贼阵亡', false, run.players[3]:isAlive())
    lt.assertEquals('还没结束', nil, run.game:getResult())
end)

lt.test('胜负：反贼与内奸全部阵亡 ⇒ 主公方胜', function ()
    local run = startGame()

    kill(run, run.players[3])
    kill(run, run.players[4])

    local result = assert(run.game:getResult(), '游戏没有结束')
    lt.assertEquals('胜方是主公方', '主公方', result.side)
    lt.assertEquals('理由', '反贼与内奸全部阵亡', result.reason)
end)

lt.test('胜负：主公阵亡 ⇒ 反贼胜', function ()
    local run = startGame()

    kill(run, run.players[1])

    local result = assert(run.game:getResult(), '游戏没有结束')
    lt.assertEquals('胜方是反贼', '反贼', result.side)
    lt.assertEquals('理由', '主公阵亡', result.reason)
end)

lt.test('胜负：主公阵亡且只剩内奸 ⇒ 内奸胜', function ()
    local run = startGame()

    kill(run, run.players[3])
    lt.assertEquals('反贼死了还不算结束', nil, run.game:getResult())

    kill(run, run.players[2])
    lt.assertEquals('内奸还活着，也不结束', nil, run.game:getResult())

    kill(run, run.players[1])

    local result = assert(run.game:getResult(), '游戏没有结束')
    lt.assertEquals('胜方是内奸', '内奸', result.side)
    lt.assertEquals('只剩内奸活着', 1, #run.desk.alivePlayers)
end)

lt.test('游戏结束：结束把流程就地收掉', function ()
    local probe <close> = useProbe()
    write('流程包/流程.lua', [[
game:registerFlow(function ()
    local player = game.desk:getPlayer(1)
    local count  = 0
    while count < 20 do
        local ask = game:ask(player, '测试', {})
        if ask.reply == nil then
            return
        end
        count = count + 1
        game:setValue('问过几次', count)
    end
end)
]])

    local game = newProbeGame { '流程包' }
    game:on('决策-询问', function (ask)
        moe.await.sleep(0) -- 让出一次：流程此刻正挂在这条询问上
        ask:answer('继续')
    end)

    local task = game:runFlow()
    lt.assertEquals('流程挂在询问上，还没走完第一轮', nil, game:getValue('问过几次'))

    game:endGame { side = '反贼', reason = '测试' }

    lt.assertEquals('结果记下了', '反贼', assert(game:getResult()).side)
    lt.assertFailed('流程以取消收尾', task)
    lt.assertEquals('流程没有继续跑', nil, game:getValue('问过几次'))
end)

lt.test('奖惩：杀死反贼的凶手摸 3 张', function ()
    local run    = startGame()
    local killer = run.players[1]
    local hand   = assert(killer:getZone('手牌'))
    local before = hand:count()

    kill(run, run.players[3])

    lt.assertEquals('凶手摸了 3 张', before + 3, hand:count())
end)

lt.test('奖惩：主公杀死忠臣 ⇒ 主公弃掉所有手牌', function ()
    local run  = startGame()
    local hand = assert(run.players[1]:getZone('手牌'))
    local pile = assert(run.game:getZone('弃牌'))
    local before = hand:count()

    kill(run, run.players[2])

    lt.assertEquals('主公手牌清空', 0, hand:count())
    lt.assertEquals('牌都进了弃牌', before, pile:count())
end)

lt.test('奖惩：凶手已阵亡时照发，但一张也摸不到', function ()
    local run    = startGame()
    local killer = run.players[4]         -- 内奸
    local hand   = assert(killer:getZone('手牌'))
    local before = hand:count()

    killer:setAlive(false)
    run.game:damage(killer, run.players[3], 10)   -- 反贼死，凶手已阵亡

    lt.assertEquals('奖励照发但摸牌被拦', before, hand:count())
end)

lt.test('奖惩：自杀不奖惩', function ()
    local run    = startGame()
    local victim = run.players[3]         -- 反贼
    local hand   = assert(victim:getZone('手牌'))
    local before = hand:count()

    run.game:damage(victim, victim, 10)

    lt.assertEquals('自己打自己不摸牌', before, hand:count())
end)

lt.test('奖惩：排在胜负判定之前（反贼是最后一个死的）', function ()
    local run    = startGame()
    local killer = run.players[1]
    local hand   = assert(killer:getZone('手牌'))
    local before = hand:count()

    kill(run, run.players[4])              -- 内奸：无奖励
    kill(run, run.players[3])              -- 反贼：有奖励，且这一下让主公方胜

    lt.assertEquals('游戏已结束', '主公方', assert(run.game:getResult()).side)
    lt.assertEquals('结束前那 3 张照摸到了', before + 3, hand:count())
end)
