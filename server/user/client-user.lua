--- 真实玩家的代表：把询问下发给客户端、等客户端回话
---@class ClientUser : User
---@field client Client # 他走的那条连接
local M = Class 'ClientUser'

Extends('ClientUser', 'User')

--- 他看得见的那份牌（懒建：第一次读的时候按座位建一份）
---@type CardSync.View?
M.cardView = nil

---@param self ClientUser
---@return CardSync.View? # 他看得见的那份牌
---@return true # 将结果缓存下来
M.__getter.cardView = function (self)
    return New 'CardSync.View' (self), true
end

function M:notify(method, params)
    self.client:notify(method, params)
end

--- 玩家基础信息变了
---@param data Proto.Notify.Player.Update
function M:playerUpdate(data)
    self.client:notify('Player.Update', data)
end

--- 玩家的自定义数据变了（一人一条）
---@param data Proto.Notify.Player.UpdateCustom
function M:playerUpdateCustom(data)
    self.client:notify('Player.UpdateCustom', data)
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

---@param moves Zone.Move[]
function M:moveCards(moves)
    self.cardView:moveCards(moves)
end

---@param cards Card[]
function M:updateCards(cards)
    self.cardView:updateCards(cards)
end


return M
