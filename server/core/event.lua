---@class Event
---@field private events table<string, SimpleEvent>
local M = Class 'Event'

function M:__init()
    self.events = {}
end

---@return Event
function M.create()
    return New 'Event' ()
end

---@param name string
---@param callback fun(...)
---@return function # 撤销这次注册
function M:on(name, callback)
    local instance = self.events[name]
    if not instance then
        instance = moe.sevent.create()
        self.events[name] = instance
    end
    return instance:on(callback)
end

---@param name string
---@param ... any
function M:fire(name, ...)
    local instance = self.events[name]
    if not instance then
        return
    end
    instance:fire(...)
end

---@param name string
---@return boolean
function M:has(name)
    return self.events[name] ~= nil
end

---@return string[] # 已注册过的时机名，按名字排序
function M:getNames()
    ---@type string[]
    local names = {}
    for name in pairs(self.events) do
        names[#names+1] = name
    end
    table.sort(names)
    return names
end

function M:clear()
    self.events = {}
end

return M
