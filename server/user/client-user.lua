require 'user.user'

--- 真实玩家的代表：把询问下发给客户端、等客户端回话
---@class ClientUser : User
---@field client Client # 他走的那条连接
local M = Class 'ClientUser'

Extends('ClientUser', 'User')

---@param client Client
function M:__init(client)
    self.client = client
end

--- 玩家数据变了：基础信息合成一条、custom 一人一条
---@param data Proto.Notify.Update
function M:update(data)
    if data.base then
        self.client:notify('Player.Update', { players = data.base })
    end
    if data.custom then
        for _, entry in ipairs(data.custom) do
            self.client:notify('Player.UpdateCustom', entry)
        end
    end
end

---@param data Proto.Notify.Card.Create
function M:cardCreate(data)
    self.client:notify('Card.Create', data)
end

---@param data Proto.Notify.Card.Update
function M:cardUpdate(data)
    self.client:notify('Card.Update', data)
end

---@param data Proto.Notify.Card.Remove
function M:cardRemove(data)
    self.client:notify('Card.Remove', data)
end

---@param data Proto.Notify.Card.Move
function M:cardMove(data)
    self.client:notify('Card.Move', data)
end

return M
