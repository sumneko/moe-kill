---@class SimpleEvent
---@field private events fun(...)[]
---@field private onError fun(err: any): any
local M = Class 'SimpleEvent'

---@param onError? fun(err: any): any # 回调报错怎么处理（默认记日志）
function M:__init(onError)
    self.events  = {}
    self.onError = onError or log.error
end

---@param callback fun(...)
---@return function unsubscribe
function M:on(callback)
    table.insert(self.events, callback)
    return function ()
        for i, cb in ipairs(self.events) do
            if cb == callback then
                table.remove(self.events, i)
                return
            end
        end
    end
end

---@param callback fun(...)
---@return function unsubscribe
function M:once(callback)
    local unsubscribe
    unsubscribe = self:on(function (...)
        unsubscribe()
        callback(...)
    end)
    return unsubscribe
end

function M:fire(...)
    for _, callback in ipairs(self.events) do
        local results = table.pack(xpcall(callback, self.onError, ...))
        if results[1] and results[2] ~= nil then
            return table.unpack(results, 2, results.n)
        end
    end
end

return {
    ---@param onError? fun(err: any): any
    ---@return SimpleEvent
    create = function (onError)
        return New 'SimpleEvent' (onError)
    end,
}
