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

--- 要若干名角色：问客户端（候选摆进参数，再把回包的 id 转回 `Player`）
---@async
---@param ask AskPlayer
---@return Player[]?
function M:askPlayer(ask)
    local game = assert(self.game)
    ---@type integer[]
    local ids = {}
    for _, player in ipairs(ask.options) do
        ids[#ids + 1] = player.id
    end
    ---@type Proto.Request.Ask.Player
    local request = {
        cancelid = game:nextId(),
        reason   = ask.reason,
        players  = ids,
        min      = ask.condition.min,
        max      = ask.condition.max,
    }
    local result = self.client:awaitRequest('Ask.Player', request)
    if not result then
        return nil
    end
    ---@type Player[]
    local answer = {}
    for _, id in ipairs(assert(result).players) do
        answer[#answer + 1] = assert(game:getPlayerById(id), '答复里的玩家不在这一局里')
    end
    return answer
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
