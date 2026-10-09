---@class Desk: Class.Base
---@field package seats table<integer, Player>
---@field package count integer
---@field package game Game # 属于哪一局
local M = Class 'Desk'

---@param game Game
---@param count integer
function M:__init(game, count)
    self.game  = game
    self.seats = {}
    self.count = count
end

---@return integer # 总共几个座位
function M:getCount()
    return self.count
end

--- 让某个玩家坐到某个座位上
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
end

--- 这个座位上坐着谁
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

--- 他坐在几号位
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

--- 下一个参与行动的人
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

--- 按行动顺序排好的一批角色（起点先、绕一圈；同一个角色写几次就排几次，同一角色占多个座位只算一趟）
---@param allowed Player[]? # 要排的角色（不传 = 桌上所有参与行动的）
---@param from? Player # 从谁开始（省略 = 顺序锚点）
---@return Player[]
function M:sortPlayers(allowed, from)
    from = from or self.game.turnPlayer or self.game.lastTurnPlayer or self.players[1]
    local start = self:getIndex(from)
    if not start then
        error('这个玩家不在这张桌子上', 2)
    end
    ---@type table<Player, integer> # 每个角色排在第几位（同一个角色取离起点最近的那个座位）
    local ranks = {}
    for index = 1, self.count do
        local player = self.seats[index]
        if player then
            local rank = (index - start) % self.count
            local old  = ranks[player]
            if not old or rank < old then
                ranks[player] = rank
            end
        end
    end
    ---@type Player[]
    local list = {}
    if allowed then
        for _, player in ipairs(allowed) do
            if player.acting and ranks[player] then
                list[#list + 1] = player
            end
        end
    else
        ---@type table<Player, boolean>
        local seen = {}
        for index = 1, self.count do
            local player = self.seats[index]
            if player and player.acting and not seen[player] then
                seen[player] = true
                list[#list + 1] = player
            end
        end
    end
    table.sort(list, function (a, b)
        return ranks[a] < ranks[b]
    end)
    return list
end

--- 按行动顺序依次给出下一个角色（迭代器）：只给参与行动的（阵亡者总是跳过）
---@param allowed Player[]? # 再收窄到这批角色（不传表示不额外收窄；**同一个角色写几次就给几次** —— 用牌的目标列表允许重复）
---@param from Player? # 从谁开始，不传表示从顺序锚点开始（当前回合角色，回合结束后是上一个；都没开过回合就从 1 号位起）
---@return fun(): Player? # 按行动顺序依次给出下一个角色（绕回自己就结束）
function M:actionOrder(allowed, from)
    local list = self:sortPlayers(allowed, from)
    local step = 0
    return function ()
        while true do
            step = step + 1
            local player = list[step]
            if not player then
                return nil
            end
            if player.acting then
                return player
            end
        end
    end
end

--- 两个座位的距离
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

--- 建一张桌子
---@param game Game
---@param count integer
---@return Desk
function moe.desk.create(game, count)
    if type(count) ~= 'number' or math.type(count) ~= 'integer' or count < 1 then
        error('桌子需要正整数个座位：{}' % { tostring(count) }, 2)
    end
    return New 'Desk' (game, count)
end
