-- 【五谷丰登】（标准版）
-- 出牌阶段，对所有角色使用。你亮出牌堆顶等同于目标角色数的牌，然后每名目标角色获得其中一张；
-- 使用结算结束后，将其中剩余的牌置入弃牌堆。

---@param remaining Card[]
---@param card Card
---@return Card[] # 去掉一张之后的剩余
local function without(remaining, card)
    ---@type Card[]
    local left = {}
    for _, item in ipairs(remaining) do
        if item ~= card then
            left[#left + 1] = item
        end
    end
    return left
end

Card '五谷丰登'
    : extends '锦囊牌'
    : on('获取目标', function (ctx)
        return game.desk.alivePlayers
    end)
    : on('结算前', function (ctx)
        ---@type Card[] # 亮出的这批牌此刻不属于任何区，先记在这次用牌上
        local revealed = game:getZone('抽牌'):draw(#ctx.targets)
        ctx:setTag('剩余', revealed)
    end)
    : on('生效', function (ctx)
        local use = assert(ctx.parent)
        ---@type Card[]
        local remaining = assert(use:getTag('剩余'))
        local card = game:askCard(ctx.target, '五谷丰登', { cards = remaining }).card
        if not card then
            return
        end
        use:setTag('剩余', without(remaining, card))
        game:moveCard(card, assert(ctx.target:getZone('手牌'), '目标没有手牌区'))
    end)
    : on('结算后', function (ctx)
        ---@type Card[]
        local remaining = assert(ctx:getTag('剩余'))
        if #remaining > 0 then
            game:moveCard(remaining, '弃牌')
        end
    end)
