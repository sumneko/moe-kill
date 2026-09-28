-- 弃牌阶段：手牌数降到体力值

---@param player Player
local function discardPhase(player)
    local hand  = player:getZone('手牌')
    local extra = hand:count() - player:getAttr('体力')
    if extra <= 0 then
        return
    end

    local ask   = game:ask(player, '弃牌', { count = extra })
    local reply = ask.reply
    local cards = reply and reply.cards
    if not cards or #cards ~= extra then
        -- 答得不对（没答 / 张数不对）就由服务器替他弃：手牌从前往后数
        local handCards = hand:list()
        cards = {}
        for i = 1, extra do
            cards[i] = handCards[i]
        end
    end
    game:moveCard(cards, '弃牌')
end

game:on('阶段-开始', function (phase)
    if phase.name == '弃牌' then
        discardPhase(phase.player)
    end
end)
