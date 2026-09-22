local PHASES = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }
local DRAW_COUNT = 2

---@type integer # 一个出牌阶段最多出这么多次（规则上可能有能无限用牌的技能，这里是终止条件）
local MAX_PLAY_COUNT = 1000

---@param player Player
---@return AskCard.Option[] # 此刻能用的牌与各自的可用目标
local function usableOptions(player)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    ---@type AskCard.Option[]
    local options = {}
    for _, card in ipairs(hand:list()) do
        local ok, _, legalTargets = game:canUse(player, card)
        if ok then
            options[#options + 1] = { card = card, targets = legalTargets }
        end
    end
    return options
end

---@param player Player
local function playPhase(player)
    for _ = 1, MAX_PLAY_COUNT do
        local options = usableOptions(player)
        if #options == 0 then
            return
        end
        local ask  = game:askCard(player, '出牌', options)
        local card = ask.card
        if not card then
            return
        end
        local used = game:useCard(player, card, ask.targets or {})
        if used.err then
            return
        end
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
