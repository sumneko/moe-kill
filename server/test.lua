---@class Test
---@field filter? string
---@field loopTicks integer
test = {}

---@type { name: string, message: string }[]
test.failures = {}

---@type string[]
test.loadedModules = {}

test.loopTicks = 0

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

function test.enableMemoryGuard()
    if not moe.args.MEM_LIMIT then
        return
    end
    if debug.gethook() then
        return
    end
    local memLimitKB = moe.args.MEM_LIMIT * 1024 * 1024
    debug.sethook(function ()
        local heapKB = collectgarbage('count')
        if heapKB > memLimitKB then
            io.write('[内存护栏] Lua 堆 {%.1f} GB 超过上限 {%.1f} GB，强制退出\n' % {
                heapKB / 1024 / 1024,
                memLimitKB / 1024 / 1024,
            })
            io.flush()
            os.exit(1)
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

test.enableMemoryGuard()

test.require 'test.smoke'
test.require 'test.session'
test.require 'test.async'
test.require 'test.core'

local bodyDone = false
local bodyFailures = 0
local caseTotal = 0
local stopResults = {}

---@async
moe.await.call(function ()
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
end)

moe.eventLoop.addTask(function ()
    test.loopTicks = test.loopTicks + 1
    if bodyDone and not stopResults[1] then
        stopResults[1] = moe.eventLoop.stop()
        stopResults[2] = moe.eventLoop.stop()
    end
end)

moe.eventLoop.start(moe.eventLoopOptions(), log.error)

if not bodyDone then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '事件循环未返回控制权（协程未执行完）',
    }
end

if test.loopTicks == 0 then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '注册的任务没有被执行',
    }
end

if stopResults[1] ~= true or stopResults[2] ~= false then
    test.failures[#test.failures + 1] = {
        name    = '事件循环',
        message = '停止语义异常：首次 {}，重复 {}' % {
            tostring(stopResults[1]),
            tostring(stopResults[2]),
        },
    }
end

if test.filter and caseTotal == 0 then
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
