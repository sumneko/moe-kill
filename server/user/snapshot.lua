--- 整局快照：客户端要一次「现在长什么样」（开局 / 重连 / 纠错都走它）

---@class Snapshot.API
moe.snapshot = {}

--- 这一局（外壳在开局时接上 —— 还没接上就是空）
---@type Game?
moe.snapshot._game = nil

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
        players    = players,
        cards      = assert(user.cardView).snapshot,
        turnPlayer = game.turnPlayer?.id,
        phase      = game.phase?.name,
    }
end

--- 这条连接控制着谁（座位不多，直接找）
---@param game Game
---@param client Client
---@return User? # 他控制着谁
---@return Player? # 他那个座位（给了他就一定有）
function moe.snapshot.userOf(game, client)
    for _, player in ipairs(game.desk.players) do
        local user = player.user
        if user and user.client == client then
            return user, player
        end
    end
end

--- 协议处理器拿「这条连接是谁」：还没开局 / 这条连接还没入座就给个能原样回回去的错误
---@param client Client
---@return User? # 他控制着谁
---@return Player? # 他那个座位（给了他就一定有）
---@return Proto.Error? # 用不了的原因
function moe.snapshot.requireUser(client)
    local game = moe.snapshot._game
    if not game then
        return nil, nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '还没开局' }
    end
    local user, player = moe.snapshot.userOf(game, client)
    if not user then
        return nil, nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '这条连接还没入座' }
    end
    return user, player
end

moe.client.register('Game.SnapShot', function (client)
    local user, _, err = moe.snapshot.requireUser(client)
    if not user then
        return nil, err
    end
    return moe.snapshot.build(user.game, user)
end)
