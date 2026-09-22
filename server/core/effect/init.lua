---@class Effect: GCHost, Class.Base
---@field kind string # 种类标识（基类给默认值，子类在自己的构造里覆盖）
---@field game Game # 这次效果所属的局
---@field parent? Effect # 外层效果：这个效果是在哪个效果的结算里被结算的（栈空时结算则为「不存在」）
---@field result? any # 结果：这次结算给出的那个值（子类可在结算中途就定下）
---@field err? any # 失败：出错时记在这儿（等它的人也会收到这个错误）
---@field package task? Task # 这次结算的任务：驱动、完成、叫醒等待者都归它
local M = Class 'Effect'

Extends(M, 'GCHost')

M.deep = 1

---@type integer # 效果最多嵌套多少层（安全阀：实测再深一点进程会直接没，见 references/architecture.md 第 12 节）
M.MAX_DEPTH = 150

---@param game Game
function M:__init(game)
    self.kind  = 'effect'
    self.game  = game
    ---@type Effect[]
    self.childs = {}
end

function M:__del()
    self.task?:cancel()
end

--- 驱动这次结算（要等外部输入时它会挂在那儿，回来时不一定结完）
---@return Effect # 它自己
function M:apply()
    if not IsValid(self) then
        return self
    end
    if self.task then
        return self
    end
    if self.game:getResult() then
        self.task = moe.task.create { effect = self }
        self.task:cancel()
        return self
    end
    local parent = moe.task.getCurrentTask()?.context.effect
    self.parent = parent
    self.task = moe.task.create { effect = self }

    self.task:execute(function ()
        local flush <close> = moe.util.defer(function () self.game:flushDying() end)
        if parent then
            parent:addChildEffect(self)
            if self.deep > M.MAX_DEPTH then
                log.warn('效果嵌套超过 {} 层，这次生效没有结算' % { M.MAX_DEPTH })
                self.task:cancel()
            end
        else
            self.game:addEffect(self)
        end
        self.game:fire('即将生效', self)
        return self:settle()
    end)

    self.task:bindGC(self)
    self:bindGC(self.task)

    return self
end

---@param effect Effect
function M:addChildEffect(effect)
    self.childs[#self.childs+1] = effect
    effect.deep = self.deep + 1
end

---@param self Effect
---@return any
M.__getter.result = function (self)
    assert(self.task, '效果还没有发动')
    return self.task.result
end

---@param self Effect
---@return any
M.__getter.err = function (self)
    assert(self.task, '效果还没有发动')
    return self.task.err
end

--- 等它结完；结果读 `.result`，失败读 `.err`
---@async
---@return Effect # 它自己
function M:await()
    if not IsValid(self) then
        return self
    end
    if not self.task then
        self:apply()
    end
    self.task:await()

    return self
end

--- 取消这次生效。如果移除的是当前效果，那么之后的代码再也不会被执行。
function M:remove()
    Delete(self)
end

--- 让这次生效以「不成立」收尾：原因记进 `.err`（不是报错），并就地停住执行体
---@param reason any # 不成立的原因
function M:reject(reason)
    local task = assert(self.task, '效果还没有发动')
    task:reject(reason)
    if moe.task.getCurrentTask() == task then
        coroutine.yield()
    end
end

--- 结算这次效果：返回值就是这次结算的结果
function M:settle()
    error('效果子类必须实现 settle', 2)
end
