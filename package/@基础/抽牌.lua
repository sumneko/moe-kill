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

game:on('摸牌', function (draw)
    local deck = assert(game:getZone('抽牌'), '局上没有抽牌区')
    local hand = assert(draw.player:getZone('手牌'), '这个玩家没有手牌区')
    ---@type Card[]
    local cards = {}
    for _ = 1, draw.count do
        if deck:count() == 0 and not recycleDiscard() then
            break
        end
        cards[#cards + 1] = deck:takeTop()
    end
    if #cards > 0 then
        game:moveCard(cards, hand)
    end
end)
