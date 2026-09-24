---@class LTest
---@field registry LTest.Case[]
---@field cardId integer # 用例造牌时自己发的号（只管别撞上）
---@field errorCount integer # 到目前为止记下的错误日志条数
---@field expectedErrors integer # 当前用例声明预期的错误日志条数
---@field errors any[] # 收到的错误（用例自己清）
---@field currentName? string # 正在跑的用例名（看门狗报告卡住时用）
---@field gameInstance? Game # 用例共用的那个局（懒建）
local M = {}

---@class LTest.Case
---@field name string
---@field callback fun()

M.registry = {}

M.errorCount     = 0
M.expectedErrors = 0
M.errors         = {}
M.cardId         = 0

--- 造一张只给用例用的牌（号是测试自己发的，用例不关心具体值）
---@param name? any
---@return Card
function M.card(name)
    M.cardId = M.cardId + 1
    return moe.card.create(M.game(), name, M.cardId)
end

--- 用例共用的一个局：牌区必须有个局才建得起来，但只测牌区本身的用例不关心这局是什么
---@return Game
function M.game()
    if not M.gameInstance then
        M.gameInstance = moe.game.create {
            seats  = 2,
            random = moe.random.create(1),
        }
    end
    return M.gameInstance
end

--- 造一个只给用例用的普通牌区
---@return Zone
function M.zone()
    return moe.zone.create(M.game())
end

--- 造一个只给用例用的有序牌区
---@return OrderedZone
function M.orderedZone()
    return moe.orderedZone.create(M.game())
end

--- 清掉攒下来的错误
function M.clearErrors()
    for i = #M.errors, 1, -1 do
        M.errors[i] = nil
    end
end

---@param message string
function M.onError(message)
    M.errorCount = M.errorCount + 1
end

---@param count integer # 声明这个用例里预期会有几条错误日志（不声明就是 0 条）
function M.expectErrors(count)
    M.expectedErrors = count
end

---@param value any
---@return string
function M.view(value)
    if type(value) == 'string' then
        return '{value%q}' % { value = value }
    end
    return tostring(value)
end

---@param name string
---@param callback async fun()
function M.test(name, callback)
    M.registry[#M.registry + 1] = {
        name     = name,
        callback = callback,
    }
end

---@param name string
---@param expect any
---@param actual any
function M.assertEquals(name, expect, actual)
    if expect ~= actual then
        error('{}: 期望 {}，实际 {}' % { name, M.view(expect), M.view(actual) }, 2)
    end
end

---@param name string
---@param unexpected any
---@param actual any
function M.assertNotEquals(name, unexpected, actual)
    if unexpected == actual then
        error('{}: 不应等于 {}' % { name, M.view(unexpected) }, 2)
    end
end

---@param name string
---@param callback fun()
---@return string? errMsg
function M.assertError(name, callback)
    local ok, err = pcall(callback)
    if ok then
        error('{}: 期望抛错但没有' % { name }, 2)
    end
    return tostring(err)
end

--- 断言这次调用以「失败」结束（不抛，错误记在 `.err` 上）
---@param name string
---@param effect Effect|Task # 任何记着 `.err` 的东西（效果 / 任务）
function M.assertFailed(name, effect)
    M.assertEquals(name, true, effect.err ~= nil)
end

---@async
---@return integer failedCount
---@return integer total
function M.runAll()
    local failedCount = 0
    for i = 1, #M.registry do
        local case   = M.registry[i]
        local before = M.errorCount
        M.expectedErrors = 0
        M.currentName = case.name
        local ok, err = xpcall(case.callback, debug.traceback)
        local logged = M.errorCount - before
        if ok and logged ~= M.expectedErrors then
            ok  = false
            err = '用例期间有 {} 条错误日志，声明的是 {} 条' % { logged, M.expectedErrors }
        end
        if ok then
            io.write('  [通过] {}\n' % { case.name })
        else
            failedCount = failedCount + 1
            io.write('  [失败] {}\n{}\n' % { case.name, tostring(err) })
        end
    end
    return failedCount, #M.registry
end

return M
