local PHASES = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }
local DRAW_COUNT = 2

---@return boolean # 洗回了没有（弃牌也空就没得洗）
local function recycleDiscard()
    local deck    = assert(game:getZone('抽牌'), '局上没有抽牌区')
    local discard = assert(game:getZone('弃牌'), '局上没有弃牌区')
    if discard:count() == 0 then
        return false
    end
    game:moveCard(discard:list(), '抽牌')
    deck:shuffle()
    return true
end

---@param player Player
---@param count integer
local function draw(player, count)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    ---@type Card[]
    local cards = {}
    for _ = 1, count do
        if deck:count() == 0 and not recycleDiscard() then
            break
        end
        cards[#cards + 1] = deck:takeTop()
    end
    if #cards > 0 then
        game:moveCard(cards, hand)
    end
end

---@param player Player
local function playPhase(player)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    while true do
        local ask   = game:ask(player, '出牌', { cards = hand:list() })
        local reply = ask.reply
        if reply == nil then
            return
        end
        if not reply.card then
            error('出牌答复里没有牌', 2)
        end
        game:useCard(player, reply.card, reply.targets or {})
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
            draw(player, DRAW_COUNT)
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
