---@class Moe.Desk
---@field private seats table<integer, Moe.Player>
---@field private count integer
local M = Class 'Moe.Desk'

---@param count integer
function M:__init(count)
    self.seats = {}
    self.count = count
end

---@param count integer
---@return Moe.Desk
function M.create(count)
    if type(count) ~= 'number' or math.type(count) ~= 'integer' or count < 1 then
        error('桌子需要正整数个座位：{}' % { tostring(count) }, 2)
    end
    return New 'Moe.Desk' (count)
end

---@return integer
function M:getCount()
    return self.count
end

---@param index integer
---@param player Moe.Player
function M:sit(index, player)
    if type(index) ~= 'number' or math.type(index) ~= 'integer' or index < 1 or index > self.count then
        error('座位号必须是 1 到 {} 之间的整数：{}' % { self.count, tostring(index) }, 2)
    end
    if self.seats[index] then
        error('座位 {} 上已经有人了' % { index }, 2)
    end
    self.seats[index] = player
end

---@param index integer
---@return Moe.Player?
function M:getPlayer(index)
    return self.seats[index]
end

---@return Moe.Player[] # 按座位号升序，含不参与行动者
function M:getPlayers()
    ---@type Moe.Player[]
    local players = {}
    for index = 1, self.count do
        local player = self.seats[index]
        if player then
            players[#players+1] = player
        end
    end
    return players
end

---@param player Moe.Player
---@return integer?
function M:getIndex(player)
    for index = 1, self.count do
        if self.seats[index] == player then
            return index
        end
    end
    return nil
end

---@param player Moe.Player
---@return Moe.Player? # 下一个参与行动的玩家，没有则返回「不存在」
function M:getNext(player)
    local index = self:getIndex(player)
    if not index then
        error('这个玩家不在这张桌子上', 2)
    end
    for step = 1, self.count do
        local nextIndex  = (index - 1 + step) % self.count + 1
        local nextPlayer = self.seats[nextIndex]
        if nextPlayer and nextPlayer:isActing() then
            return nextPlayer
        end
    end
    return nil
end

---@param from Moe.Player
---@param to Moe.Player
---@return integer # 两个方向取较小值，最小为 1
function M:getDistance(from, to)
    local a = self:getIndex(from)
    local b = self:getIndex(to)
    if not a or not b then
        error('座位距离只在坐在桌上的两个玩家之间求值', 2)
    end
    local diff     = math.abs(a - b)
    local distance = math.min(diff, self.count - diff)
    if distance < 1 then
        distance = 1
    end
    return distance
end

return M
