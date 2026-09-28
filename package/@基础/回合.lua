-- 回合流程：一个「回合」对象 + 六个阶段（进出各发一个时机）；各阶段业务见「阶段」目录
local PHASES = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }

---@class Turn
---@field player Player # 这个回合属于谁
---@field private skippedPhases table<string, true> # 这个回合里要跳过的阶段
local Turn = Class 'Turn'

---@param game Game
---@param player Player
function Turn:__init(game, player)
    self.game          = game
    self.player        = player
    self.skippedPhases = {}
end

-- 记一笔：这个回合里「name」阶段跳过
---@param name string
function Turn:skipPhase(name)
    self.skippedPhases[name] = true
end

-- 读掉一笔跳过：有就清掉并回真
---@param name string
---@return boolean
function Turn:takePhaseSkip(name)
    if not self.skippedPhases[name] then
        return false
    end
    self.skippedPhases[name] = nil
    return true
end

---@class Player
---@field turn? Turn # 他正在进行的那个回合（不在他的回合就是空）

---@param player Player
local function runTurn(player)
    local turn = New 'Turn' (game, player)
    player.turn         = turn
    game.turnPlayer     = player
    game.lastTurnPlayer = player
    game:fire('回合-开始', { player = player })
    for _, name in ipairs(PHASES) do
        if not player:isAlive() then
            break
        end
        if turn:takePhaseSkip(name) then
            goto continue
        end
        local _ <close> = game:enterPhase(player, name)
        ::continue::
    end
    game:fire('回合-结束', { player = player })
    game.turnPlayer = nil
    player.turn     = nil
end

game:registerFlow(function ()
    local player = game.desk:getPlayer(1)
    while player and #game.desk.alivePlayers > 1 do
        runTurn(player)
        player = game.desk:getNext(player)
    end
end)
