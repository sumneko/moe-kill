--- 调试用的杂项入口（**只有调试模式**能调）：目前只有「列牌名」与「给自己发一张牌」

--- 这一局能造的牌名（定义里有、去掉被继承的模板类，按名字去重并排序）
---@param game Game
---@return string[]
local function cardNames(game)
    local defs = game:getCardDefs()
    ---@type table<string, true>
    local bases = {}
    for _, def in ipairs(defs) do
        local base = def.extendsName
        if base then
            bases[base] = true
        end
    end
    ---@type string[]
    local names = {}
    ---@type table<string, true>
    local seen = {}
    for _, def in ipairs(defs) do
        if not seen[def.name] and not bases[def.name] then
            seen[def.name] = true
            names[#names + 1] = def.name
        end
    end
    table.sort(names)
    return names
end

--- 调试模式且已入座的那个玩家（不齐就把错误给出去）
---@param client Client
---@return Player?
---@return Proto.Error?
local function requirePlayer(client)
    if not moe.debug then
        return nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '只有调试模式能这么干' }
    end
    local _, player, err = moe.snapshot.requireUser(client)
    return player, err
end

moe.client.register('Debug.Cards', function (client)
    local player, err = requirePlayer(client)
    if not player then
        return nil, err
    end
    ---@type Proto.Result.Debug.Cards
    return { cards = cardNames(player.game) }
end)

moe.client.register('Debug.GiveCard', function (client, params)
    ---@cast params Proto.Request.Debug.GiveCard
    local player, err = requirePlayer(client)
    if not player then
        return nil, err
    end
    local game = player.game
    if not moe.util.arrayHas(cardNames(game), params.name) then
        return nil, { code = moe.jsonrpc.INVALID_PARAMS, message = '没有叫「' .. params.name .. '」的牌' }
    end
    local card = game:createCard(params.name)
    game:moveCard(card, player:getZone('手牌'))
    ---@type Proto.Result.Debug.GiveCard
    return {}
end)
