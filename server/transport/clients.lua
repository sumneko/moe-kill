--- 一组客户端连接：登记 / 注销 / 广播（每人一份载荷）
---@class Clients : Class.Base
---@field private list Client[]
local M = Class 'Clients'

function M:__init()
    self.list = {}
end

--- 登记一条连接（返回撤销这次登记的函数）
---@param client Client
---@return fun()
function M:add(client)
    self.list[#self.list + 1] = client
    local removed = false
    return function ()
        if removed then
            return
        end
        removed = true
        self:remove(client)
    end
end

--- 注销一条连接
---@param client Client
function M:remove(client)
    for i, item in ipairs(self.list) do
        if item == client then
            table.remove(self.list, i)
            return
        end
    end
end

--- 给每条连接各发一条（载荷按连接各造一份；造出来是空的那条就跳过）
---@param method string
---@param build fun(client: Client): any
function M:broadcast(method, build)
    for _, client in ipairs(moe.util.copy(self.list)) do
        local params = build(client)
        if params ~= nil then
            client:notify(method, params)
        end
    end
end

---@class Clients.API
moe.clients = {}

---@return Clients
function moe.clients.create()
    return New 'Clients' ()
end

return moe.clients
