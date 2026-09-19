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
---@field answers? any[] # 脚本化的答案（按顺序作答；省略时一律答 false = 不响应）

---@param answers any[]?
---@return fun(ask: Ask): any
local function scripted(answers)
    local index = 0
    return function ()
        index = index + 1
        if not answers then
            return false
        end
        if index > #answers then
            error('脚本里没有更多答案了', 2)
        end
        return answers[index]
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
    game.answerer = scripted(options.answers)
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
