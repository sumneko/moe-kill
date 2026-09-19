---@class LTest
---@field registry LTest.Case[]
local M = {}

---@class LTest.Case
---@field name string
---@field callback fun()

M.registry = {}

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

---@async
---@return integer failedCount
---@return integer total
function M.runAll()
    local failedCount = 0
    for i = 1, #M.registry do
        local case = M.registry[i]
        local ok, err = xpcall(case.callback, debug.traceback)
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
