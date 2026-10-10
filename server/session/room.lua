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
    end
    local game = moe.game.create {
        seats    = options.seats,
        random   = moe.random.create(options.seed or 1),
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

--- 一条连接坐进来：占一个空座、接上下行，回一份快照（坐满就开局）
---@param client Client
---@param options? Room.JoinOptions
---@return Proto.SnapShot
function moe.room.join(client, options)
    local game  = assert(moe.room._game, '还没有开局')
    local index = assert(freeSeat(game), '座位已经坐满')
    local player = moe.player.create(game, {
        attributes = game:getAttributeSystem():createInstance(),
        name       = options?.name,
    })
    game.desk:sit(index, player)
    player:setUser(New 'ClientUser' (game, client))
    local user = assert(player.user)
    user:attach()
    if not freeSeat(game) then
        moe.room.start()
    end
    return moe.snapshot.build(game, user)
end

--- 开局：定身份 / 发牌 / 起流程（坐满时自动调，也可以自己调）
---@param prepare? 身份场.准备配置
function moe.room.start(prepare)
    local game = assert(moe.room._game, '还没有开局')
    game:fire('游戏-准备', { config = prepare })
    game:fire('游戏-开始', {})
    game:runFlow()
end
