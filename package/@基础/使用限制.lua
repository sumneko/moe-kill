---@type table<string, integer> # 每个出牌阶段每种牌名最多用几次
local PLAY_PHASE_LIMIT = {
    ['杀'] = 1,
}

---@type string # 阶段内的计数挂在这个标签上（作用域 = 一个出牌阶段）
local COUNT_TAG = '本阶段用过'

---@param player Player
---@param name string
---@return integer
local function usedCount(player, name)
    local counts = player:getTag(COUNT_TAG)
    if not counts then
        return 0
    end
    return counts[name] or 0
end

game:on('阶段-开始', function (ctx)
    if ctx.phase == '出牌' then
        ctx.player:setTag(COUNT_TAG, {})
    end
end)

game:on('阶段-结束', function (ctx)
    if ctx.phase == '出牌' then
        ctx.player:removeTag(COUNT_TAG)
    end
end)

game:on('卡牌-能否使用', function (ctx)
    local name  = ctx.card:getLabel()
    local limit = PLAY_PHASE_LIMIT[name]
    if not limit then
        return
    end
    if usedCount(ctx.user, name) >= limit then
        return '本阶段已经用过「{}」了' % { name }
    end
end)

game:on('卡牌-结算前', function (ctx)
    local name = ctx.card:getLabel()
    if not PLAY_PHASE_LIMIT[name] then
        return
    end
    local counts = ctx.user:getTag(COUNT_TAG)
    if counts then
        counts[name] = (counts[name] or 0) + 1
    end
end)
