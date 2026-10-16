--- 房间：开一局、让客户端坐进来（装配与开局的入口）

---@class Room.OpenOptions
---@field seats integer # 座位数
---@field packages? string[] # 要装的包（省略 = 默认清单）
---@field sources? string[] # 包来源（省略 = 默认来源）
---@field seed? integer # 随机种子

---@class Room.JoinOptions
---@field name? string # 玩家名

---@class Room.API
moe.room = {}

--- 这一局（`open` 时接上 —— 还没开就是空）
---@type Game?
moe.room._game = nil

--- 这一局用的随机种子（重开一局时拿它 +1）
---@type integer
moe.room._seed = 1

--- 开一局：建局 + 装配 + 让协议层认识它（先不开局，等人齐）
---@param options Room.OpenOptions
---@return Game
function moe.room.open(options)
    if not moe.room._registered then
        moe.room._registered = true
        moe.client.register('Game.Join', function (client, params)
            ---@cast params Room.JoinOptions?
            return moe.room.join(client, params)
        end)
        moe.client.register('Game.Restart', function ()
            return moe.room.restart()
        end)
    end
    local seed = options.seed or 1
    moe.room._seed = seed
    local game = moe.game.create {
        seats    = options.seats,
        random   = moe.random.create(seed),
        sources  = options.sources,
        packages = options.packages,
    }
    moe.snapshot.attach(game)
    moe.room._game = game
    return game
end

--- 找个空座（都坐满就是空）
---@param game Game
---@return integer?
local function freeSeat(game)
    for i = 1, game.desk:getCount() do
        if not game.desk:getPlayer(i) then
            return i
        end
    end
end

--- 让一条连接坐到某个座位（造人 + 接上下行）
---@param game Game
---@param index integer
---@param client Client
---@param name? string
---@return Player
---@return ClientUser
local function seatPlayer(game, index, client, name)
    local player = moe.player.create(game, {
        attributes = game:getAttributeSystem():createInstance(),
        name       = name,
    })
    local user = New 'ClientUser' (game, client)
    game.desk:sit(index, player)
    player:setUser(user)
    user:attach()
    return player, user
end

--- 找一个「同名、而且他那条连接已经断了」的座位（重连接管它；测试 / 电脑没有 client，不算离线）
---@param game Game
---@param name string
---@return Player?
local function findOffline(game, name)
    for _, player in ipairs(game.desk.players) do
        local user = player.user
        if player:getName() == name and user and user.client and user.client.closed then
            return player
        end
    end
end

--- 接管一个断了线的座位：座位与角色一行不动，只把背后的 user 换成新连接
---@param game Game
---@param player Player
---@param client Client
---@return Proto.SnapShot
local function reseat(game, player, client)
    local user = New 'ClientUser' (game, client)
    player:setUser(user)
    user:attach()
    log.info('接了回来：{}（座位 {}）' % { player:getName() or '?', game.desk:getIndex(player) })
    return moe.snapshot.build(game, user)
end

--- 一条连接坐进来：占一个空座、接上下行，回一份快照（坐满就开局）；还没开局 / 没空位就把原因回给客户端
---@param client Client
---@param options? Room.JoinOptions
---@return Proto.SnapShot?
---@return Proto.Error?
function moe.room.join(client, options)
    local game = moe.room._game
    if not game then
        return nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '还没有开局' }
    end
    -- 同名且他那条连接已经断了 ⇒ 接管那个座位（座位与角色都不动，只换背后的 user）
    local name = options?.name
    local back = name and findOffline(game, name)
    if back then
        return reseat(game, back, client)
    end
    local index = freeSeat(game)
    if not index then
        return nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '座位已经坐满' }
    end
    local _, user = seatPlayer(game, index, client, options?.name)
    if not freeSeat(game) then
        -- 开局延到下一笔调度：这一包的回包与房间广播先出去（开局要跑一整局，不能抢在它们前头）
        moe.await.wake(function ()
            if moe.room._game == game and not game:getResult() then
                moe.room.start()
            end
        end)
    end
    moe.roomSync.broadcast(game)
    return moe.snapshot.build(game, user)
end

--- 开局：定身份 / 发牌 / 起流程（坐满时自动调，也可以自己调）
---@param prepare? 身份场.准备配置
function moe.room.start(prepare)
    local game = assert(moe.room._game, '还没有开局')
    -- 开局要跑到这局结束（里头会挂在询问上）：放它自己的协程里，别占着叫它的那条
    moe.await.call(function ()
        game:fire('游戏-准备', { config = prepare })
        game:fire('游戏-开始', {})
        game:runFlow()
    end)
end

--- 把已经终了的这一局放下、原班人马重开一局（座位 / 名字 / 配置与包都沿用，种子另取）
---@return table? # 收条（重建走 `Game.Restarted` 通知）
---@return Proto.Error?
function moe.room.restart()
    local game = moe.room._game
    if not game then
        return nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '还没有开局' }
    end
    if not game:getResult() then
        return nil, { code = moe.jsonrpc.INVALID_REQUEST, message = '这一局还没结束' }
    end
    ---@type { index: integer, name: string?, client: Client }[]
    local roster = {}
    for index = 1, game.desk:getCount() do
        local player = game.desk:getPlayer(index)
        if player then
            local client = player.user?.client
            if client then
                roster[#roster + 1] = { index = index, name = player:getName(), client = client }
            end
        end
    end
    local next = moe.room.open {
        seats    = game.desk:getCount(),
        packages = game.list,
        sources  = game.sources,
        seed     = moe.room._seed + 1,
    }
    for _, seat in ipairs(roster) do
        seatPlayer(next, seat.index, seat.client, seat.name)
    end
    log.info('重开一局：{} 人 / 包 {} / 种子 {}' % {
        next.desk:getCount(),
        table.concat(next.list, ','),
        moe.room._seed,
    })
    moe.roomSync.broadcast(next)
    for _, seat in ipairs(roster) do
        local user = assert(next.desk:getPlayer(seat.index)).user
        ---@cast user ClientUser
        user:notify('Game.Restarted', moe.snapshot.build(next, user))
    end
    if #roster > 0 then
        -- 原班人马都在座上了 ⇒ 直接开局（延后一笔调度：收条与快照先出去）
        moe.await.wake(function ()
            if moe.room._game == next and not next:getResult() then
                moe.room.start()
            end
        end)
    end
    return {}
end
