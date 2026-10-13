--- 流程下行：谁的回合、进了哪个阶段、这一局怎么结束的

---@class FlowSync.API
moe.flowSync = {}

--- 客户端接入了：把这一局的流程账带起来（重复调无害）
---@param user User
---@return Game.FlowSync
function moe.flowSync.attach(user)
    return user.game.flowSync
end

---@class Game: Class.Base
---@field package flowSync Game.FlowSync # 这一局的流程账本
local Game = Class 'Game'

---@param self Game
---@return Game.FlowSync
---@return true
Game.__getter.flowSync = function (self)
    return New 'Game.FlowSync' (self), true
end

--- 按局的账本挂在局上：`package` 可见性只给本文件看（内核不认识协议，就不写进 game.lua 了）
---@class Game.FlowSync
local S = Class 'Game.FlowSync'

---@param game Game
function S:__init(game)
    self.game = game

    game:on('回合-开始', function (turn)
        self:broadcast('Turn.Begin', { player = turn.player.id })
    end)
    game:on('回合-结束', function (turn)
        self:broadcast('Turn.End', { player = turn.player.id })
    end)
    game:on('阶段-开始', function (phase)
        self:broadcast('Phase.Begin', { player = phase.player.id, name = phase.name })
    end)
    game:on('阶段-结束', function (phase)
        self:broadcast('Phase.End', { player = phase.player.id, name = phase.name })
    end)
    game:on('游戏-结束', function (result)
        self:broadcast('Game.Over', { side = result.side, reason = result.reason })
    end)
end

--- 发给所有入座的人：这几条与视角无关，而且都是「时刻」（攒批会把两次切换压成一条，前端就播不出节奏）
---@param method string
---@param data table
function S:broadcast(method, data)
    for _, player in ipairs(self.game.desk.players) do
        local user = player.user
        if user then
            user:notify(method, data)
        end
    end
end
