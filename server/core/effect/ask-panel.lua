--- 一次回复（应答方给的）：**变化值** —— 「把这几张挪到第几行」/「选中这张」/「点确定了」
--- 由应答方从 `'面板-询问'` 里**返回**（返回空 = 不表态，问下一位）；不合法的变化由内核拒收
---@class AskPanel.Change
---@field moves? AskPanel.Move|AskPanel.Move[] # 移动型变化（一条或一批；**合法才应用**）
---@field card? Card|Card[] # 挑选型变化：改选这些（覆盖上一次的选择；空表 = 清空选择）
---@field done? boolean # 点确定了：这次询问到此为止

--- 一条移动型变化：把这串牌按这个顺序放到第 `row` 行（插到该行末尾）
--- 行内重排也能用它表达：把该行整体重放一遍
---@class AskPanel.Move
---@field cards Card|Card[] # 要挪的牌（按给定顺序）
---@field row integer # 放到第几行（1 起）

--- 定下的形状
---@class AskPanel.Result
---@field rows Card[][] # 各行（按当前顺序是这批牌；不允许移动的面板恒等于创建时的形状）
---@field card? Card # 选中那张（如有）
---@field cards Card[] # 选中的牌（没选就是空表）

---@class AskPanel.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field panel Panel # 摆在哪块面板上

--- 一次面板询问：**开着**到应答方点「确定」为止 —— 中间可以来回很多次，每次只收变化值
---@class AskPanel : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field panel Panel # 这块面板
---@field rows Card[][] # 定下的各行（`= .result.rows`）
---@field card? Card # 选中的那张牌（没选就是空；`= .result.card`）
---@field cards Card[] # 选中的牌（没选就是空表；`= .result.cards`）
---@field cancelable boolean # 这次允许主动取消吗（= 选项的 `cancelable`）
---@field private selected? Card[] # 当前选中的牌（最后一次挑选覆盖前面的）
local M = Class 'AskPanel'

Extends('AskPanel', 'Effect')

---@type integer # 一次询问最多收多少次回复（安全阀：答复不前进时兜住）
M.MAX_ROUNDS = 1000

---@param game Game
---@param to Player
---@param reason string
---@param panel Panel
function M:__init(game, to, reason, panel)
    self.game   = game
    self.kind   = 'askPanel'
    self.to     = to
    self.reason = reason
    self.panel  = panel
end

--- 定下的各行
---@return Card[][]
M.__getter.rows = function (self)
    return self.result?.rows or {}
end

--- 选中的牌（没选就是空表）
---@return Card[]
M.__getter.cards = function (self)
    return self.result?.cards or {}
end

--- 选中的那张牌（没选就是空）
---@return Card?
M.__getter.card = function (self)
    return self.result?.card
end

--- 这次允许「一个都不选」吗（`min` 为 0 ⇒ 直接确定也算成立）
---@return boolean
function M:allowNone()
    return (self.panel.options.min or 0) == 0
end

--- 这次允许主动取消吗（与 ask 系列同一套字段）
---@return boolean
M.__getter.cancelable = function (self)
    return self.panel.options.cancelable ~= false
end

--- 这块面板允不允许移动牌
---@return boolean
function M:moveable()
    return self.panel.options.moveable == true
end

--- 这块面板上要选几张
---@return integer # 至少要选几张
function M:minPick()
    return self.panel.options.min or 0
end

---@return integer # 至多能选几张
function M:maxPick()
    return self.panel.options.max or self:minPick()
end

--- 这步选牌合法吗
---@param card Card
---@return string? # 合法就是空
function M:checkPick(card)
    local cell = self.panel:findCell(card)
    if not cell then
        return '这块面板上没有这张牌'
    end
    if cell.disabled then
        return '这张牌已经被禁用了'
    end
    return nil
end

--- 这步移动合法吗（每张都要在面板上、没被禁用；行要存在）
---@param move AskPanel.Move
---@return string? # 合法就是空
function M:checkMove(move)
    local cards = moe.util.toList(move.cards)
    if #cards == 0 then
        return '这一步里没有牌'
    end
    if not self.panel.rows[move.row] then
        return '这块面板上没有第 {} 行' % { move.row }
    end
    ---@type table<Card, true>
    local seen = {}
    for _, card in ipairs(cards) do
        local problem = self:checkPick(card)
        if problem then
            return problem
        end
        if seen[card] then
            return '这一步里的牌重复了'
        end
        seen[card] = true
    end
    return nil
end

--- 把这一步生效：这些牌按给定顺序挪到目标行末尾
---@param move AskPanel.Move
function M:doMove(move)
    local row = self.panel.rows[move.row]
    for _, card in ipairs(moe.util.toList(move.cards)) do
        local cell = self.panel:takeOut(card)
        if cell then
            self.panel:appendCell(row, cell)
        end
    end
end

--- 应用一次回复里的变化：[先全验、再全应用] —— 有一条不合法就整条回复作废，面板保持原样
---@param change AskPanel.Change
---@return string? # 不合法时给出原因
function M:applyChange(change)
    local moves = change.moves ~= nil and moe.util.toList(change.moves) or {}
    local picks = change.card ~= nil and moe.util.toList(change.card) or nil

    if #moves > 0 and not self:moveable() then
        return '这块面板不能移动牌'
    end
    if picks then
        if #picks > self:maxPick() then
            return '至多选中 {} 张牌' % { self:maxPick() }
        end
        ---@type table<Card, true>
        local seen = {}
        for _, card in ipairs(picks) do
            local problem = self:checkPick(card)
            if problem then
                return problem
            end
            if seen[card] then
                return '选中的牌重复了'
            end
            seen[card] = true
        end
    end
    for _, move in ipairs(moves) do
        local problem = self:checkMove(move)
        if problem then
            return problem
        end
    end

    for _, move in ipairs(moves) do
        self:doMove(move)
    end
    if picks then
        self.selected = picks
    end
    return nil
end

--- 确定时的校验：选中的张数够不够
---@return string? # 合法就是空
function M:checkDone()
    if #(self.selected or {}) < self:minPick() then
        return '至少要选中 {} 张牌' % { self:minPick() }
    end
    return nil
end

--- 定下结果
function M:resolveResult()
    ---@type Card[][]
    local rows = {}
    for _, row in ipairs(self.panel.rows) do
        ---@type Card[]
        local cards = {}
        for _, cell in ipairs(row.cells) do
            cards[#cards + 1] = cell.card
        end
        rows[#rows + 1] = cards
    end
    local selected = self.selected or {}
    self.task:resolve {
        rows  = rows,
        card  = selected[1],
        cards = selected,
    }
end

--- 把询问交给应答方：**开着**收回复（每次只收变化值），直到点了「确定」为止
---@async
function M:settle()
    local rounds = 0
    while true do
        local answer = self.to.user?:askPanel(self)
                    or self.game:fire('面板-询问', self)
        if answer == nil then
            -- 没人表态：允许「一个都不选」就当空答复（成立），否则算取消
            -- （不允许取消的询问连取消入口都没有：记成拒收）
            if not self:allowNone() then
                self.task:reject(self.cancelable and '取消' or '这次询问必须给出答复')
                return
            end
            break
        end
        if type(answer) ~= 'table' then
            self.task:reject('答复必须是一张表（`{ moves = ..., card = ..., done = ... }`）')
            return
        end

        local problem = self:applyChange(answer)
        if problem then
            self.task:reject(problem)
            return
        end
        self.game:fire('面板-答复', self)

        if answer.done then
            local doneProblem = self:checkDone()
            if doneProblem then
                self.task:reject(doneProblem)
                return
            end
            break
        end

        rounds = rounds + 1
        if rounds >= M.MAX_ROUNDS then
            self.task:reject('面板询问开得太久（没有点确定）')
            return
        end
    end
    self:resolveResult()
end

---@class AskPanel.API
moe.askPanel = {}

---@param options AskPanel.CreateOptions
---@return AskPanel
function moe.askPanel.create(options)
    return New 'AskPanel' (options.game, options.to, options.reason, options.panel)
end
