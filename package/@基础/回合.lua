-- 回合流程：六个阶段 + 摸牌 + 出牌阶段的驱动（问牌 / 用牌）+ 弃牌阶段
local PHASES = { '准备', '判定', '摸牌', '出牌', '弃牌', '结束' }
local DRAW_COUNT = 2

---@type integer # 一个出牌阶段最多出这么多次（规则上可能有能无限用牌的技能，这里是终止条件）
local MAX_PLAY_COUNT = 1000

---@type AskCard.Condition # 手牌里那些（能不能用由缘由 '使用' 决定，选项带各自的可用目标）
local PLAY_PHASE_CONDITION = { zone = '手牌' }

---@param player Player
local function playPhase(player)
    for _ = 1, MAX_PLAY_COUNT do
        local ask  = game:askCard(player, '使用', PLAY_PHASE_CONDITION)
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
    game.turnPlayer     = player
    game.lastTurnPlayer = player
    game:fire('回合-开始', { player = player })
    for _, name in ipairs(PHASES) do
        local _ <close> = game:enterPhase(player, name)
        if name == '摸牌' then
            game:draw(player, DRAW_COUNT)
        elseif name == '出牌' then
            playPhase(player)
        elseif name == '弃牌' then
            discardPhase(player)
        end
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
