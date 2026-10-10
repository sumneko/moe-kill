--- user 侧测试的公共夹具：一对真客户端（内存 Link，帧走真协议）+ 两人局 + 发牌
---@class Test.UserSupport
local M = {}

local lt = require 'test.ltest'

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
function M.connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 搭一个两人局：每人坐好、都接了客户端并接入下行
---@param sources? string[] # 包来源（省略 = 只装公共牌定义）
---@return Game
---@return Player[]
function M.newGame(sources)
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = sources or { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local _, back = M.connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
    end
    return game, players
end

--- 发两张候选牌并搬进他的手牌（他那份卡牌视图账里才有号）
---@async
---@param game Game
---@param player Player
---@return Card
---@return Card
function M.dealCards(game, player)
    local c1 = game:createCard('杀', '黑桃', 7)
    local c2 = game:createCard('闪', '红桃', 2)
    game:moveCard({ c1, c2 }, player:getZone('手牌'))
    moe.await.sleep(0)
    return c1, c2
end

return M
