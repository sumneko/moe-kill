-- 选将：`'游戏-准备'` 里定武将 —— 主公先选（备选 = 全部「君主」+ 随机 N 张其他），其余按座位依次
-- 选走的不再出现（互斥）；没被选走的那些就是官方的「武将牌堆」
-- 载荷可以带 `config.heroes`（座位号 → 武将名）：点名了的直接装、不再询问；`config.skipSelect` 则整段跳过
Depends { './开局' }

--- 从一批武将里随机抽 n 张（洗一份副本 ⇒ 同一个随机源可复现）
---@param list HeroDef[]
---@param n integer
---@return HeroDef[]
local function pickRandom(list, n)
    local copy = table.copy(list)
    game.random:shuffle(copy)
    ---@type HeroDef[]
    local picked = {}
    for i = 1, math.min(n, #copy) do
        picked[#picked + 1] = copy[i]
    end
    return picked
end

--- 把一位武将从名单里摘掉
---@param list HeroDef[]
---@param hero HeroDef
local function takeOut(list, hero)
    for i, one in ipairs(list) do
        if one == hero then
            table.remove(list, i)
            return
        end
    end
end

--- 这名角色这次能看到的备选（已被选走的不在里面）
---@param player Player
---@param free HeroDef[] # 还没被选走的（保序）
---@param n integer # 备选数
---@return HeroDef[]
local function candidatesFor(player, free, n)
    if player.identity ~= '主公' then
        return pickRandom(free, n)
    end
    ---@type HeroDef[]
    local lords = {}
    ---@type HeroDef[]
    local others = {}
    for _, hero in ipairs(free) do
        if hero:isKind('君主') then
            lords[#lords + 1] = hero
        else
            others[#others + 1] = hero
        end
    end
    for _, hero in ipairs(pickRandom(others, n)) do
        lords[#lords + 1] = hero
    end
    return lords
end

game:on('游戏-准备', function (event)
    local config = event.config or {}
    if config.skipSelect then
        return
    end

    local seats = game.desk.players
    ---@type HeroDef[] # 还能给的武将（按 `game:getHeroes` 的顺序）
    local free = game:getHeroes()

    -- 载荷里点名了的：直接装、不问
    for seatIndex, name in pairs(config.heroes or {}) do
        local hero = assert(game:getHero(name), '武将池里没有「{}」' % { name })
        seats[seatIndex]:setHero(hero)
        takeOut(free, hero)
    end

    local count = game:getValue('选将备选数') or 5

    ---@type Player[] # 主公先选，然后其余按座位依次
    local queue = {}
    for i = 1, #seats do
        local player = seats[i]
        if player.identity == '主公' then
            table.insert(queue, 1, player)
        else
            queue[#queue + 1] = player
        end
    end

    for _, player in ipairs(queue) do
        if not player.hero then
            local candidates = candidatesFor(player, free, count)
            assert(#candidates > 0, '武将不够分了')
            -- 没人答（超时 / 取消）就服务器替他拿第一张
            local chosen = game:askHero(player, '选将', { hero = candidates }).hero or candidates[1]
            takeOut(free, chosen)
            player:setHero(chosen)
        end
    end
end)
