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
