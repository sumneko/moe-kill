---@class LTest
---@field registry LTest.Case[]
local m = {}

---@class LTest.Case
---@field name string
---@field callback fun()

m.registry = {}

---@param value any
---@return string
function m.view(value)
    if type(value) == 'string' then
        return '{value%q}' % { value = value }
    end
    return tostring(value)
end

---@param name string
---@param callback async fun()
function m.test(name, callback)
    m.registry[#m.registry + 1] = {
        name     = name,
        callback = callback,
    }
end

---@param name string
---@param expect any
---@param actual any
function m.assertEquals(name, expect, actual)
    if expect ~= actual then
        error('{}: 期望 {}，实际 {}' % { name, m.view(expect), m.view(actual) }, 2)
    end
end

---@param name string
---@param unexpected any
---@param actual any
function m.assertNotEquals(name, unexpected, actual)
    if unexpected == actual then
        error('{}: 不应等于 {}' % { name, m.view(unexpected) }, 2)
    end
end

---@param name string
---@param callback fun()
---@return string? errMsg
function m.assertError(name, callback)
    local ok, err = pcall(callback)
    if ok then
        error('{}: 期望抛错但没有' % { name }, 2)
    end
    return tostring(err)
end

---@async
---@return integer failedCount
---@return integer total
function m.runAll()
    local failedCount = 0
    for i = 1, #m.registry do
        local case = m.registry[i]
        local ok, err = xpcall(case.callback, debug.traceback)
        if ok then
            io.write('  [通过] {}\n' % { case.name })
        else
            failedCount = failedCount + 1
            io.write('  [失败] {}\n{}\n' % { case.name, tostring(err) })
        end
    end
    return failedCount, #m.registry
end

return m
