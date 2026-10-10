--- 整局快照：客户端要一次「现在长什么样」（开局 / 重连 / 纠错都走它）

---@class Snapshot.API
moe.snapshot = {}

--- 盯住某一局（外壳在开局时调；一个 VM 一局）
---@param game Game
function moe.snapshot.attach(game)
    moe.snapshot._game = game
end

--- 拼一个玩家的协议形状（基础信息 + 按收件人视角裁的自由数据）
---@param player Player
---@param viewer Player
---@return Proto.Player
local function toPlayer(player, viewer)
    return {
        base   = moe.playerSync.toBase(player),
        custom = player.custom:allVisibles(viewer),
    }
end

--- 拼一份快照（收件人视角）
---@param game Game
---@param user User
---@return Proto.SnapShot
function moe.snapshot.build(game, user)
    ---@type Proto.Player[]
    local players = {}
    for _, player in ipairs(game.desk.players) do
        players[#players + 1] = toPlayer(player, assert(user.player))
    end
    return {
        players = players,
        cards   = assert(user.cardView).snapshot,
    }
end

--- 这条连接控制着谁（座位不多，直接找）
---@param game Game
---@param client Client
---@return User?
function moe.snapshot.userOf(game, client)
    for _, player in ipairs(game.desk.players) do
        local user = player.user
        if user and user.client == client then
            return user
        end
    end
end

moe.client.register('Game.SnapShot', function (client)
    local game = assert(moe.snapshot._game, '还没开局')
    local user = assert(moe.snapshot.userOf(game, client), '这条连接还没入座')
    return moe.snapshot.build(game, user)
end)
