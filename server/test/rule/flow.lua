local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'flow-probe'

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
local function newGame(items)
    return moe.game.create {
        desk     = moe.desk.create(2),
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = items,
    }
end

lt.test('流程：登记后启动能拿到返回值', function ()
    local probe <close> = useProbe()
    write('流程包/流程.lua', [[
game:registerFlow(function ()
    return '跑完了'
end)
]])

    local game = newGame { '流程包' }
    local task = game:runFlow()
    task:await()

    lt.assertEquals('流程的返回值就是这次任务的结果', '跑完了', task.result)
    lt.assertEquals('流程不进记牌器（它是驱动，不是结算）', 0, #game:getEffects())
end)

lt.test('流程：挂起中可以从外面停掉', function ()
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

    local game = newGame { '流程包' }
    game.events:on('决策-询问', function (ask)
        moe.await.sleep(0) -- 让出一次：流程此刻正挂在这条询问上
        ask:answer('继续')
    end)

    local task = game:runFlow()

    lt.assertEquals('流程挂在询问上，还没走完第一轮', nil, game:getValue('问过几次'))

    task:cancel()

    lt.assertFailed('停掉后以取消结束', task)
    lt.assertEquals('流程没有继续跑', nil, game:getValue('问过几次'))
end)

lt.test('流程：加载之外不能登记', function ()
    local probe <close> = useProbe()
    write('流程包/流程.lua', 'game:setValue("占位", true)')

    local game = newGame { '流程包' }
    lt.assertError('非加载期登记报错', function ()
        game:registerFlow(function () end)
    end)
end)

lt.test('流程：没有登记就启动会失败', function ()
    local probe <close> = useProbe()
    write('流程包/流程.lua', 'game:setValue("占位", true)')

    local game = newGame { '流程包' }
    lt.assertError('没登记流程', function ()
        game:runFlow()
    end)
end)

lt.test('流程：清空重装后不再有流程', function ()
    local probe <close> = useProbe()
    write('流程包/流程.lua', 'game:registerFlow(function () return "第一次" end)')
    write('空包/空文件.lua', 'game:setValue("占位", true)')

    local game = newGame { '流程包' }
    local task = game:runFlow()
    task:await()
    lt.assertEquals('第一次装载的流程能跑', '第一次', task.result)

    moe.loader.install(game, { sources = { probeDir:string() .. '/*' }, packages = { '空包' } })

    lt.assertError('重装后没有流程了', function ()
        game:runFlow()
    end)
end)
