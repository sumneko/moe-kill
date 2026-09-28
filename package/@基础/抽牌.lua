-- 摸牌：Draw 类与玩家身上的 draw；把 count 张从抽牌堆顶抽给他

---@class Draw : Effect
---@field player Player # 谁摸牌
---@field count integer # 摸几张
local Draw = Class('Draw', 'Effect')

---@param game Game
---@param player Player
---@param count integer
function Draw:__init(game, player, count)
    self.kind   = 'draw'
    self.player = player
    self.count  = count
end

--- 摸牌结算
---@async
function Draw:settle()
    -- 已阵亡的不摸
    if not self.player:isAlive() then
        return
    end
    self.game:drawCards(self.player, self.count)
end

---@class Player
local Player = Class 'Player'

--- 摸一次牌
---@async
---@param count integer # 摸几张
---@return Draw
function Player:draw(count)
    local draw = New 'Draw' (self.game, self, count)
    draw:apply():await()
    return draw
end
