local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@class Test.FlowSync.Got
---@field method string
---@field params table
---@field front Client # 谁收到的

--- 收一串方法的下行（按收到的顺序记下来）
---@param methods string[]
---@return Test.FlowSync.Got[]
---@return fun()
local function collect(methods)
    ---@type Test.FlowSync.Got[]
    local got = {}
    ---@type fun()[]
    local undos = {}
    for _, method in ipairs(methods) do
        undos[#undos + 1] = moe.client.register(method, function (client, params)
            got[#got + 1] = { method = method, params = params, front = client }
        end)
    end
    return got, function ()
        for _, undo in ipairs(undos) do
            undo()
        end
    end
end

--- 只看方法名
---@param got Test.FlowSync.Got[]
---@return string[]
local function methodsOf(got)
    ---@type string[]
    local methods = {}
    for _, one in ipairs(got) do
        methods[#methods + 1] = one.method
    end
    return methods
end

---@async
lt.test('流程下行：回合 / 阶段 / 结局各一条，发给入座的人', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])
    local extra = select(1, support.connect())

    local got, undo = collect { 'Turn.Begin', 'Turn.End', 'Phase.Begin', 'Phase.End', 'Game.Over' }
    local _ <close> = moe.util.defer(undo)

    game:fire('回合-开始', { player = me })
    do
        local phase <close> = game:enterPhase(me, '出牌')
        lt.assertEquals('进阶段这事记下了', true, phase.name == '出牌')
    end
    game:fire('回合-结束', { player = me })
    game:endGame { side = '主公方', reason = '反贼与内奸全部阵亡' }
    moe.await.sleep(0)

    ---@type Test.FlowSync.Got[]
    local mine = {}
    ---@type integer
    local stray = 0
    for _, one in ipairs(got) do
        if one.front == front then
            mine[#mine + 1] = one
        elseif one.front == extra then
            stray = stray + 1
        end
    end

    lt.assertEquals('两条入座的都各收一份', 10, #got)
    lt.assertEquals('没入座的那条收不到', 0, stray)
    lt.assertEquals('五条都到齐了', 5, #mine)
    lt.assertEquals('顺序：回合开始', 'Turn.Begin', assert(mine[1]).method)
    lt.assertEquals('说的是他', me.id, assert(mine[1]).params.player)
    lt.assertEquals('顺序：阶段开始', 'Phase.Begin', assert(mine[2]).method)
    lt.assertEquals('说的是那个阶段', '出牌', assert(mine[2]).params.name)
    lt.assertEquals('顺序：阶段结束', 'Phase.End', assert(mine[3]).method)
    lt.assertEquals('顺序：回合结束', 'Turn.End', assert(mine[4]).method)
    lt.assertEquals('顺序：结局', 'Game.Over', assert(mine[5]).method)
    lt.assertEquals('胜负依据原样带来', '反贼与内奸全部阵亡', assert(mine[5]).params.reason)
end)

---@async
lt.test('流程下行：真跑一局，回合与阶段成对来，结局收尾', function ()
    local got, undo = collect { 'Turn.Begin', 'Turn.End', 'Phase.Begin', 'Phase.End', 'Game.Over' }
    local _ <close> = moe.util.defer(undo)

    -- 所有询问一律「不答」：流程才走得下去（空回包 = 答不出来）
    ---@type fun()[]
    local stubs = {}
    for _, method in ipairs { 'Ask.Hero', 'Ask.Select', 'Ask.Use', 'Ask.UseSkill', 'Ask.Panel', 'Ask.Choice' } do
        stubs[#stubs + 1] = moe.client.register(method, function ()
            return {}
        end)
    end
    local _ <close> = moe.util.defer(function ()
        for _, stub in ipairs(stubs) do
            stub()
        end
    end)

    local game = moe.room.open { seats = 4, seed = 1, packages = { '身份场', '标准' } }
    ---@type Client[]
    local clients = {}
    -- 收摊（断言失败也照跑）：流程是无尽的（四人都在），不收掉它会一直转、拖死后面的用例
    local _ <close> = moe.util.defer(function ()
        game:endGame { side = '平局', reason = '用例收摊' }
        for _, client in ipairs(clients) do
            client:close('用例收摊')
        end
    end)

    for i = 1, 4 do
        local front, back = support.connect()
        clients[#clients + 1] = front
        clients[#clients + 1] = back
        front:awaitRequest('Game.Join', { name = '玩家' .. i })
    end
    -- 谁都不出牌 ⇒ 牌会在抽牌堆 / 手牌 / 弃牌堆之间转，转空了 `@基础/牌堆.lua` 自己判平局收场
    for _ = 1, 30 do
        moe.await.sleep(0)
        if game:getResult() then
            break
        end
    end
    if not game:getResult() then
        game:endGame { side = '平局', reason = '用例收摊' }
    end
    for _ = 1, 3 do
        moe.await.sleep(0)
    end

    -- 四个前端各收一份同样的流：只看第一个的（数一份才是「回合有没有成对」）
    local watcher = assert(clients[1])
    ---@type Test.FlowSync.Got[]
    local mine = {}
    for _, one in ipairs(got) do
        if one.front == watcher then
            mine[#mine + 1] = one
        end
    end

    lt.assertEquals('开局第一件事就是报回合开始', 'Turn.Begin', assert(mine[1]).method)
    local begins, ends = 0, 0
    ---@type integer
    local overs = 0
    for _, one in ipairs(mine) do
        if one.method == 'Turn.Begin' then
            begins = begins + 1
        elseif one.method == 'Turn.End' then
            ends = ends + 1
        elseif one.method == 'Game.Over' then
            overs = overs + 1
        elseif one.method == 'Phase.Begin' then
            local name = one.params.name
            lt.assertEquals('阶段名是规则里那六个之一', true,
                name == '准备' or name == '判定' or name == '摸牌' or name == '出牌' or name == '弃牌' or name == '结束')
        end
    end
    lt.assertEquals('真的跑了回合', true, begins > 0)
    lt.assertEquals('除了被打断的那个，回合都收了尾', true, begins - ends <= 1)
    lt.assertEquals('结局只报一次', 1, overs)
    lt.assertEquals('结局是最后一条', 'Game.Over', assert(mine[#mine]).method)
    lt.assertEquals('结局说的是平局', '平局', assert(mine[#mine]).params.side)
end)
