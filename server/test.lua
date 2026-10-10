---@class Test
---@field filter? string
---@field loopTicks integer
test = {}

---@type { name: string, message: string }[]
test.failures = {}

---@type string[]
test.loadedModules = {}

test.loopTicks = 0

-- 装载缓存（测试期专用；产品代码不动）
require 'test.iocache'.enable()

local target = moe.args.TEST
if type(target) == 'string' then
    test.filter = 'test.' .. target:gsub('%.lua$', ''):gsub('[/\\]', '.')
end

---@param modname string
---@return boolean
function test.matchFilter(modname)
    local filter = test.filter
    if not filter then
        return true
    end
    if modname == filter then
        return true
    end
    if modname:sub(1, #filter + 1) == filter .. '.' then
        return true
    end
    if filter:sub(1, #modname + 1) == modname .. '.' then
        return true
    end
    return false
end

---@param modname string
function test.require(modname)
    if not test.matchFilter(modname) then
        return
    end
    test.loadedModules[#test.loadedModules + 1] = modname
    io.write('测试模块: {}\n' % { modname })
    local ok, err = xpcall(require, debug.traceback, modname)
    if not ok then
        test.failures[#test.failures + 1] = {
            name    = modname,
            message = tostring(err),
        }
    end
end

-- 两个护栏共用同一个上限：CPU 时间（防死循环）与墙钟（防卡在等待里）
-- 2026-10-08 先因为全量到 ~10.3 秒抬到 15；同日做完「按需装包 + 测试期装载缓存」后回到 10（全量 ~3.4 秒）
local timeLimit = 10

function test.enableGuards()
    if debug.gethook() then
        return
    end
    -- 内存上限默认也给一个：死循环里调用方的 CPU 护栏要等到下一个指令计数点才叫，堆却可能几秒就涨到几十 GB
    local memLimitKB = (moe.args.MEM_LIMIT or 2048) * 1024 * 1024
    local startClock = os.clock()
    debug.sethook(function ()
        if memLimitKB then
            local heapKB = collectgarbage('count')
            if heapKB > memLimitKB then
                io.write('[护栏] Lua 堆 {%.1f} GB 超过上限 {%.1f} GB，强制退出\n' % {
                    heapKB / 1024 / 1024,
                    memLimitKB / 1024 / 1024,
                })
                io.flush()
                os.exit(1)
            end
        end
        local passed = os.clock() - startClock
        if passed > timeLimit then
            error('测试跑了 {} 秒还没完，当成卡住处理' % { timeLimit }, 2)
        end
    end, '', 100000)
end

local function report()
    io.write('\n')
    if #test.failures > 0 then
        io.write('失败汇总:\n')
        for _, failure in ipairs(test.failures) do
            io.write('  {}\n{}\n' % { failure.name, failure.message })
        end
    end
    if test.filter and #test.loadedModules == 0 then
        io.write('过滤器 "{}" 没有匹配到任何测试模块\n' % { test.filter })
    end
end

local lt = require 'test.ltest'

moe.task.setErrorHandler(function (err)
    lt.errors[#lt.errors + 1] = err
end)

test.require 'test.smoke'
test.require 'test.util'
test.require 'test.session'
test.require 'test.transport.jsonrpc'
test.require 'test.transport.link'
test.require 'test.transport.client'
test.require 'test.transport.clients'
test.require 'test.async'
test.require 'test.core'
test.require 'test.core.event'
test.require 'test.core.desk'
test.require 'test.core.player'
test.require 'test.core.user'
test.require 'test.core.custom'
test.require 'test.user.client-user'
test.require 'test.user.card-sync'
test.require 'test.user.snapshot'
test.require 'test.user.skill-sync'
test.require 'test.user.ask-player'
test.require 'test.user.ask-card'
test.require 'test.user.ask-card-with-target'
test.require 'test.user.ask-choice'
test.require 'test.user.ask-play-card'
test.require 'test.user.ask-use-card'
test.require 'test.user.ask-use-card-to-card'
test.require 'test.user.view-as'
test.require 'test.core.game'
test.require 'test.core.game-over'
test.require 'test.core.can-use'
test.require 'test.core.card-def'
test.require 'test.core.phase'
test.require 'test.core.effect'
test.require 'test.core.effect.cast'
test.require 'test.core.effect.damage'
test.require 'test.core.effect.heal'
test.require 'test.core.effect.draw'
test.require 'test.core.effect.dying'
test.require 'test.core.effect.ask'
test.require 'test.core.effect.ask-card'
test.require 'test.core.effect.ask-choice'
test.require 'test.core.effect.ask-player'
test.require 'test.core.effect.ask-use-card'
test.require 'test.core.effect.ask-card-with-target'
test.require 'test.core.effect.ask-use-card-to-card'
test.require 'test.core.effect.ask-use-skill'
test.require 'test.core.effect.ask-play-card'
test.require 'test.core.effect.ask-panel'
test.require 'test.core.effect.ask-hero'
test.require 'test.core.effect.play'
test.require 'test.core.effect.use-card-to-card'
test.require 'test.rule'
test.require 'test.rule.vfs'
test.require 'test.rule.routing'
test.require 'test.rule.event'
test.require 'test.rule.meta'
test.require 'test.rule.flow'
test.require 'test.rule.base'
test.require 'test.rule.identity'
test.require 'test.rule.select-hero'
test.require 'test.rule.setup'
test.require 'test.rule.hero'
test.require 'test.rule.hero-skill'
test.require 'test.rule.skill'
test.require 'test.rule.slash'
test.require 'test.rule.equip'
test.require 'test.rule.turn'
test.require 'test.rule.trick'
test.require 'test.rule.dying'
test.require 'test.rule.draw'
test.require 'test.rule.game-over'
test.require 'test.rule.judge'
test.require 'test.rule.delayed-trick'
test.require 'test.rule.death'

local bodyDone = false
local bodyFailures = 0
local caseTotal = 0
local stopResults = {}
local stuckAt

--- 把虚拟时钟推进 seconds 秒（测试里时间**冻结** —— 不显式推进，定时任务永远不会到点）
---@param seconds number
function test.advance(seconds)
    moe.timer.update(moe.timer.clock() + seconds * 1000)
end

-- 看门狗走真墙钟（虚拟时钟下定时器不会自己到点，不能用 timer.wait）
local startWallClock = os.clock()

---@async
moe.await.call(function ()
    test.enableGuards()
    local ok, first, second = xpcall(lt.runAll, debug.traceback)
    if ok then
        bodyFailures = first
        caseTotal    = second
    else
        test.failures[#test.failures + 1] = {
            name    = '测试执行',
            message = tostring(first),
        }
    end
    bodyDone = true
    -- 用例可能是在延迟队列里跑完的（await.sleep 的恢复在那儿）：这时循环正等着下一个定时任务，得当场停掉
    stopResults[1] = moe.eventLoop.stop()
    if stopResults[1] then
        stopResults[2] = moe.eventLoop.stop()
    end
end)

moe.eventLoop.addTask(function ()
    test.loopTicks = test.loopTicks + 1
    if not stuckAt and not bodyDone and os.clock() - startWallClock > timeLimit then
        stuckAt = lt.currentName or '（还没有用例在跑）'
        moe.eventLoop.stop()
    end
    if bodyDone and not stopResults[1] then
        stopResults[1] = moe.eventLoop.stop()
        stopResults[2] = moe.eventLoop.stop()
    end
end)

moe.eventLoop.start(moe.eventLoopOptions(), log.error)

if stuckAt then
    test.failures[#test.failures + 1] = {
        name    = '看门狗',
        message = '{} 秒还没跑完，卡在「{}」' % { timeLimit, stuckAt },
    }
end

if not stuckAt and not bodyDone then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '事件循环未返回控制权（协程未执行完）',
    }
end

if not stuckAt and test.loopTicks == 0 then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '注册的任务没有被执行',
    }
end

if not stuckAt and (stopResults[1] ~= true or stopResults[2] ~= false) then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '停止语义异常：首次 {}，重复 {}' % {
            tostring(stopResults[1]),
            tostring(stopResults[2]),
        },
    }
end

if not stuckAt and test.filter and caseTotal == 0 then
    test.failures[#test.failures + 1] = {
        name    = '过滤器',
        message = '过滤器 "{}" 没有匹配到任何测试用例' % { test.filter },
    }
end

io.write('\n共 {} 个用例，{} 个失败，事件循环迭代 {} 次\n' % {
    caseTotal,
    bodyFailures + #test.failures,
    test.loopTicks,
})

report()

os.exit(#test.failures == 0 and bodyFailures == 0)
