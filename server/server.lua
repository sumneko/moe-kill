--- 单局服务器：开一局、听一个端口、把每条连接接成客户端（重开要重启进程）

local socket = require 'bee.socket'
local epoll  = require 'bee.epoll'

---@class Server.Options
---@field port integer # 监听端口
---@field seats integer # 座位数
---@field packages string[] # 要装的包
---@field sources? string[] # 包来源
---@field seed? integer # 随机种子

---@class Server.API
moe.server = {}

--- 这一局（起过就是那个局 —— 单局模式不换局）
---@type Game?
moe.server._game = nil

--- 店里那些连接（还没入座的也在里面）
---@type Clients?
moe.server._clients = nil

--- 监听的那个套接字
---@type bee.socket.fd?
moe.server._listener = nil

---@type LoopWaiter.Watch?
moe.server._watch = nil

--- 收下新来的连接，接成客户端
---@private
local function acceptOne()
    while true do
        local fd, err = moe.server._listener:accept()
        if fd == false then
            return
        end
        if not fd then
            log.warn('收连接失败：{}' % { tostring(err) })
            return
        end
        ---@cast fd bee.socket.fd
        local client = moe.client.create(moe.link.tcp(fd))
        client:start()
        moe.server._clients:add(client)
    end
end

--- 起服务：开一局 + 听端口（只做单局 —— 重开要重启进程）
---@param options Server.Options
function moe.server.start(options)
    if moe.server._listener then
        error('已经起过一局了（单局模式，重开要重启进程）', 2)
    end
    local listener, createErr = socket.create 'tcp'
    if not listener then
        error('建不出监听套接字：' .. tostring(createErr), 2)
    end
    local ok, err = listener:option('reuseaddr', 1)
    if ok then
        ok, err = listener:bind('0.0.0.0', options.port)
    end
    if not ok then
        listener:close()
        error('端口 {} 听不上：{}' % { options.port, tostring(err) }, 2)
    end
    listener:listen(64)
    moe.server._listener = listener
    moe.server._clients  = moe.clients.create()
    moe.server._game     = moe.room.open {
        seats    = options.seats,
        packages = options.packages,
        sources  = options.sources,
        seed     = options.seed,
    }
    moe.server._watch = moe.loopWaiter.watch(listener, acceptOne, epoll.EPOLLIN)
    log.info('听在 {} 上（{} 人一局）' % { options.port, options.seats })
end

--- 端口听上了没有
---@return boolean
function moe.server.isStarted()
    return moe.server._listener ~= nil
end

return moe.server
