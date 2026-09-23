---@class Desk: Class.Base
---@field package seats table<integer, Player>
---@field package count integer
---@field package game? Game # 属于哪一局（bindGame 之后才有）
local M = Class 'Desk'

---@param count integer
function M:__init(count)
    self.seats = {}
    self.count = count
end

---@param game Game
function M:bindGame(game)
    self.game = game
    for i = 1, self.count do
        local player = self.seats[i]
        if player then
            player:bindGame(game)
        end
    end
end

---@return integer
function M:getCount()
    return self.count
end

---@param index integer
---@param player Player
function M:sit(index, player)
    if type(index) ~= 'number' or math.type(index) ~= 'integer' or index < 1 or index > self.count then
        error('座位号必须是 1 到 {} 之间的整数：{}' % { self.count, tostring(index) }, 2)
    end
    if self.seats[index] then
        error('座位 {} 上已经有人了' % { index }, 2)
    end
    self.seats[index] = player
    if self.game then
        player:bindGame(self.game)
    end
end

---@param index integer
---@return Player?
function M:getPlayer(index)
    return self.seats[index]
end

---@type Player[]
M.players = nil

---@param self Desk
---@return Player[]
M.__getter.players = function (self)
    local players = {}
    for i = 1, self.count do
        local player = self.seats[i]
        if player then
            players[#players+1] = player
        end
    end
    return players
end

---@type Player[]
M.alivePlayers = nil

---@param self Desk
---@return Player[]
M.__getter.alivePlayers = function (self)
    local players = {}
    for i = 1, self.count do
        local player = self.seats[i]
        if player and player:isAlive() then
            players[#players+1] = player
        end
    end
    return players
end

---@param player Player
---@return integer?
function M:getIndex(player)
    for index = 1, self.count do
        if self.seats[index] == player then
            return index
        end
    end
    return nil
end

---@param player Player
---@return Player? # 下一个参与行动的玩家，没有则返回「不存在」
function M:getNext(player)
    local index = self:getIndex(player)
    if not index then
        error('这个玩家不在这张桌子上', 2)
    end
    for step = 1, self.count do
        local nextIndex  = (index - 1 + step) % self.count + 1
        local nextPlayer = self.seats[nextIndex]
        if nextPlayer and nextPlayer.acting then
            return nextPlayer
        end
    end
    return nil
end

---@param allowed Player[]? # 允许参与的角色，不传表示都允许
---@param from Player? # 从谁开始，不传表示从当前回合角色开始
---@return fun(): Player? # 按行动顺序依次给出下一个角色（绕回自己就结束）
function M:actionOrder(allowed, from)
    if not from then
        from = self.game and self.game.turnPlayer
    end
    if not from then
        error('没有起点：此刻不在任何角色的回合里，得显式给出从谁开始', 2)
    end
    local start = self:getIndex(from)
    if not start then
        error('这个玩家不在这张桌子上', 2)
    end
    ---@type table<Player, boolean>?
    local allowedSet = nil
    if allowed then
        allowedSet = {}
        for _, player in ipairs(allowed) do
            allowedSet[player] = true
        end
    end
    ---@type table<Player, boolean>
    local visited = {}
    local step    = 0
    return function ()
        while step < self.count do
            local player = self.seats[(start - 1 + step) % self.count + 1]
            step = step + 1
            if player and not visited[player] and (not allowedSet or allowedSet[player]) then
                visited[player] = true
                return player
            end
        end
        return nil
    end
end

---@param from Player
---@param to Player
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

---@class Desk.API
moe.desk = {}

---@param count integer
---@return Desk
function moe.desk.create(count)
    if type(count) ~= 'number' or math.type(count) ~= 'integer' or count < 1 then
        error('桌子需要正整数个座位：{}' % { tostring(count) }, 2)
    end
    return New 'Desk' (count)
end
