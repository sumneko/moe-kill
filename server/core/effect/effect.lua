---@class Effect: GCHost, Class.Base
---@field kind string # 种类标识（基类给默认值，子类在自己的构造里覆盖）
---@field game Game # 这次效果所属的局
---@field from? Player # 来源：这个效果是谁发起的（没有这一方就是空）
---@field to? Player # 承受者：这个效果冲谁来的（没有这一方就是空）
---@field parent? Effect # 外层效果：这个效果是在哪个效果的结算里被结算的（栈空时结算则为「不存在」）
---@field result? any # 结果：这次结算给出的那个值（子类可在结算中途就定下）
---@field err? any # 没成立的原因（空 = 成立）：出错 / 不成立 / 被阻止 / 取消
---@field success boolean # 这次结算成不成立（= 没成立的原因为空）
---@field package task? Task # 这次结算的任务：驱动、完成、叫醒等待者都归它
---@field tempZone? Zone # 自己那块临时处理区（没要过为空 —— 要一块区请用 getTempZone）
---@field private tags table<string, any> # 标签袋（内容侧挂这次结算的临时数据）
local M = Class 'Effect'

Extends(M, 'GCHost')

M.deep = 1

---@type integer # 效果最多嵌套多少层（安全阀：实测再深一点进程会直接没，见 references/architecture.md 第 12 节）
M.MAX_DEPTH = 150

---@type integer # 一次结算最多挂多少个子结算（安全阀：与 MAX_DEPTH 一起兜住「收尾里起结算」这类自激）
M.MAX_CHILDS = 1000

---@param game Game
function M:__init(game)
    self.kind = 'effect'
    self.game = game
    self.tags = {}
    ---@type Effect[]
    self.childs = {}
end

function M:__del()
    self.task?:cancel()
end

---@param key string
---@param value any
function M:setTag(key, value)
    if type(key) ~= 'string' or key == '' then
        error('标签键必须是非空字符串', 2)
    end
    self.tags[key] = value
end

---@param key string
---@return any
function M:getTag(key)
    return self.tags[key]
end

---@param key string
function M:removeTag(key)
    self.tags[key] = nil
end

--- 这次结算自己那块临时处理区：没要过就地建；要用外层结算那块请显式写 `parent:getTempZone()`
---@return Zone
function M:getTempZone()
    local zone = self.tempZone
    if not zone then
        zone = moe.zone.create(self.game)
        self.tempZone = zone
    end
    return zone
end

---@private
function M:bindFinish()
    local task = assert(self.task, '效果还没有发动')
    local game = self.game
    local function finish()
        game:fire('效果-收尾', self)
        local zone = self.tempZone
        if not zone then
            return
        end
        -- 结算的默认收尾：内容侧没留走的牌进弃牌堆
        game:getZone('弃牌'):accept(zone:list())
    end
    task:onResolved(finish)
    task:onRejected(finish)
end

--- 问一次这个时机：返回非空就是拦（只给 false 时归一成一句通用原因）
---@private
---@param owner? Player|Game # 问谁（为空 = 没有这一方，直接跳过）
---@param name string # 时机名
---@return any # 要拦就给原因
function M:fireVeto(owner, name)
    local reason = owner?:fire(name, self)
    if reason == false then
        reason = '这次生效被阻止'
    end
    return reason
end

--- 这一层还住不下吗（嵌套太深 / 父挂的子结算太多）：返回不让它结算的原因
---@private
---@param parent Effect
---@return string?
function M:checkNesting(parent)
    if parent.deep >= M.MAX_DEPTH then
        return '效果嵌套超过 {} 层' % { M.MAX_DEPTH }
    end
    if #parent.childs >= M.MAX_CHILDS then
        return '一次结算里挂的子结算超过 {} 个' % { M.MAX_CHILDS }
    end
end

--- 驱动这次结算：排上队，下一笔调度才真正开跑；要结果就接着 `:await()`
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
        self:bindFinish()
        self.task:cancel()
        return self
    end

    ---@type Effect?
    local parent = moe.task.getCurrentTask()?.context.effect
    self.parent = parent
    if parent then
        self.deep = parent.deep + 1
    end
    self.task = moe.task.create { effect = self }

    -- 越限的那层不结算，也不绑收尾：否则「收尾里起结算」的写法会一层层涨到爆栈
    local reason = parent and self:checkNesting(parent)
    if reason then
        log.warn('{}，这次生效没有结算' % { reason })
        self.task:cancel()
        return self
    end

    self:bindFinish()

    self.task:executeAsync(function ()
        if parent then
            parent:addChildEffect(self)
        else
            self.game:addEffect(self)
        end
        local refusal = self:fireVeto(self.game, '效果-能否生效')
                     or self:fireVeto(self.from, '效果-来源-能否生效')
                     or self:fireVeto(self.to,   '效果-目标-能否生效')
        if refusal ~= nil then
            -- 有订阅者给了原因 ⇒ 这一次生效被阻止：不结算、没有结果、不算失败
            self:cancel(refusal)
            return
        end
        return self:settle()
    end)

    self.task:bindGC(self)
    self:bindGC(self.task)

    return self
end

--- 记一个子结算（只记账；进不了账的那层不会走到这里）
---@param effect Effect
function M:addChildEffect(effect)
    self.childs[#self.childs+1] = effect
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

---@param self Effect
---@return boolean
M.__getter.success = function (self)
    return self.err == nil
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

--- 让这次生效以「不成立」收尾：原因记进 `.err`（不是报错），并就地停住执行体
---@param reason any # 不成立的原因
function M:cancel(reason)
    local task = assert(self.task, '效果还没有发动')
    task:cancel(reason)
end

--- 结算这次效果：返回值就是这次结算的结果
function M:settle()
    error('效果子类必须实现 settle', 2)
end




