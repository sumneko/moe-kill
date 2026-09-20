---@class Test.RuleSupport
---@field players Player[]
---@field desk Desk
---@field random Random
---@field game Game
local M = {}

---@class Test.RuleSupport.StartOptions
---@field packages? string[] # 装载清单（省略时只装默认加载的包）
---@field count integer # 座位数
---@field sources? string[] # 包来源（省略时用默认来源）
---@field seed? integer
---@field answers? Card[] # 脚本化的答复（按顺序给出牌；省略时一律不响应）

---@param answers Card[]?
---@return fun(ask: AskCard)
local function scripted(answers)
    local index = 0
    return function (ask)
        if not answers then
            return
        end
        index = index + 1
        if index > #answers then
            error('脚本里没有更多牌了', 2)
        end
        ask:answer(answers[index])
    end
end

---@param options Test.RuleSupport.StartOptions
---@return Test.RuleSupport
function M.start(options)
    local desk   = moe.desk.create(options.count)
    local random = moe.random.create(options.seed or 1)
    local game   = moe.game.create {
        desk     = desk,
        random   = random,
        sources  = options.sources,
        packages = options.packages,
    }
    game.events:on('游戏-询问', scripted(options.answers))
    local attributeSystem = game:getAttributeSystem()
    ---@type Player[]
    local players = {}
    for i = 1, options.count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    game:fire('游戏-开始', {})
    return { players = players, desk = desk, random = random, game = game }
end

return M
