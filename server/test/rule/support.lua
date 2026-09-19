---@class Test.RuleSupport
---@field players Moe.Player[]
---@field desk Moe.Desk
---@field random Moe.Random
---@field room Moe.Room
---@field rule Moe.Rule
local M = {}

---@class Test.RuleSupport.StartOptions
---@field packages string[]? # 规则集加载清单（省略时只装默认加载的包）
---@field count integer # 座位数
---@field sources string[]? # 包来源（省略时用默认来源）
---@field seed? integer

---@param options Test.RuleSupport.StartOptions
---@return Test.RuleSupport
function M.start(options)
    local desk   = moe.desk.create(options.count)
    local random = moe.random.create(options.seed or 1)
    local room   = moe.room.create {
        desk     = desk,
        random   = random,
        sources  = options.sources,
        packages = options.packages,
    }
    local rule            = room:getRule()
    local attributeSystem = rule:getAttributeSystem()
    ---@type Moe.Player[]
    local players = {}
    for i = 1, options.count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    rule:fire('游戏-开始', {})
    return { players = players, desk = desk, random = random, room = room, rule = rule }
end

return M
