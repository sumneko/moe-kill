local PHASES = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }
local DRAW_COUNT = 2

---@param player Player
local function playPhase(player)
    while true do
        local ask  = game:askCard(player, '出牌', {})
        local card = ask.card
        if not card then
            return
        end
        game:useCard(player, card, ask.targets or {})
    end
end

---@param player Player
local function discardPhase(player)
    local hand  = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    local extra = hand:count() - player:getAttr('体力')
    if extra <= 0 then
        return
    end

    local ask   = game:ask(player, '弃牌', { count = extra })
    local reply = ask.reply
    local cards = reply and reply.cards
    if not cards or #cards ~= extra then
        error('弃牌阶段要弃 {} 张，答复的是 {} 张' % { extra, cards and #cards or 0 }, 2)
    end
    game:moveCard(cards, '弃牌')
end

---@param player Player
local function runTurn(player)
    game.turnPlayer = player
    game:resetOperations()
    game:fire('回合-开始', { player = player })
    for _, phase in ipairs(PHASES) do
        game:fire('阶段-开始', { player = player, phase = phase })
        if phase == '摸牌' then
            game:draw(player, DRAW_COUNT)
        elseif phase == '出牌' then
            playPhase(player)
        elseif phase == '弃牌' then
            discardPhase(player)
        end
        game:fire('阶段-结束', { player = player, phase = phase })
    end
    game:fire('回合-结束', { player = player })
    game.turnPlayer = nil
end

game:registerFlow(function ()
    local player = game.desk:getPlayer(1)
    while player and #game.desk.alivePlayers > 1 do
        runTurn(player)
        player = game.desk:getNext(player)
    end
end)
