---@class Effect
---@field kind string # 种类标识（基类给默认值，子类在自己的构造里覆盖）
---@field game Game # 这次效果所属的局
---@field parent? Effect # 外层效果：这个效果是在哪个效果的结算里被结算的（栈空时结算则为「不存在」）
---@field private co? thread # 结算协程：不在结算中时为「不存在」
local M = Class 'Effect'

---@param game Game
function M:__init(game)
    self.kind = 'effect'
    self.game = game
end

---@private
---@param co thread # 抛错或让出后待处理的 <close> 不会自己执行，要关一次才会执行
---@return any # 关失败时的错误（协程自己抛的错已经被拿到，不算关失败）
local function closeCo(co)
    if coroutine.status(co) == 'suspended' then
        local suc, err = coroutine.close(co)
        if not suc then
            return err
        end
        return nil
    end
    coroutine.close(co)
    return nil
end

---@private
---@param co thread # 这次结算唯一的驱动点：让出就把控制权交回这里
---@return boolean # 是否结算完（false = 这一次生效被取消）
local function drive(co)
    local ok, reason = coroutine.resume(co)
    if not ok then
        error(debug.traceback(co, reason), 0)
    end
    if coroutine.status(co) == 'dead' then
        return true
    end
    if reason ~= 'cancelled' then
        error('效果不会这样让出：{}' % { tostring(reason) }, 0)
    end
    local err = closeCo(co)
    if err then
        error(err, 0)
    end
    return false
end

function M:apply()
    local co = coroutine.create(function ()
        self.parent = self.game:getCurrentEffect()
        local pop <close> = self.game:pushEffect(self)
        self.game:fire('即将生效', self)
        self:settle()
    end)
    self.co = co
    local ok, err = pcall(drive, co)
    local closeErr = closeCo(co)
    self.co = nil
    if not ok then
        error(err, 0)
    end
    if closeErr then
        error(closeErr, 0)
    end
end

---@async
function M:remove()
    local co = self.co
    if not co then
        error('这个效果不在结算中，不能取消', 2)
    end
    if coroutine.status(co) == 'normal' then
        error('这个效果正在驱动内层结算，本批不支持从内层取消外层', 2)
    end
    if coroutine.running() ~= co and coroutine.status(co) ~= 'suspended' then
        error('这个效果已经结束，不能取消', 2)
    end
    Delete(self)
end

---@private
function M:__del()
    local co = self.co
    if not co then
        return
    end
    if coroutine.running() == co then
        coroutine.yield('cancelled')
        error('这个效果已经被取消，不该继续执行', 0)
    end
    local err = closeCo(co)
    if err then
        error(err, 0)
    end
end

function M:settle()
    error('效果子类必须实现 settle', 2)
end

---@class Effect.API
local API = {}

return API
