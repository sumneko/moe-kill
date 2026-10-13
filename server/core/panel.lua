--- 面板：把一批牌摊成若干行，可以在上面「选择 / 移动」，可以标记与禁用
--- 牌仍住在区里 —— 面板是「布局 + 交互状态」的视图，不负责搬牌（搬牌照旧 `placeTop` / `moveCard`）
--- **创建出来就广播给所有人**（内核只 fire `'面板-变化'`，协议侧照它下发）；之后只能看不能操作 —— 要操作得开一次 `askPanel`
---@alias Panel.DirtyKind 'base'|'removed'

---@class Panel : GCHost, Class.Base
---@field id integer # 协议号（创建时发；客户端靠它指认这块面板）
---@field name string # 这块面板叫什么（内容侧定，原样带到应答方）
---@field rows Panel.Row[] # 各行（`rows[1]` 是 1 号行；协议里就用行序号）
---@field cardsByRow Card[][] # 各行按顺序的牌（就是询问结果里 `rows` 那个形状）
---@field options Panel.Options # 选项（服务器不解释语义，只照它校验）
---@field private game Game
---@field private visible Visibility # 牌面的可见性（帮不上忙的就是背面朝上；**布局本身人人可见**：几行、每行几张都看得见）
---@field private disabled table<Card, true> # 被禁用的牌（仍是面板上的牌；不能再动、不能再被选）
---@field private markMap table<Card, string[]> # 牌 → 展示用标记
local M = Class 'Panel'

Extends('Panel', 'GCHost')

--- 面板上的一行（行内有序；标题只给客户端排版用）
---@class Panel.Row
---@field title? string
---@field cards Card[]

--- 面板的选项：服务器不解释语义，只照它校验
---@class Panel.Options
---@field min? integer # 确定时至少要选中几张（省略 = 0：不必选就能确定）
---@field max? integer # 确定时至多选中几张（省略 = `min`）
---@field cancelable? boolean # 允不允许主动取消（省略 = 允许；与 ask 系列同一套字段）
---@field moveable? boolean # 允不允许移动牌（省略 = 不允许：只挑不摆的面板不用开）

---@param game Game
---@param name string
---@param visible Visibility?
---@param options Panel.Options?
function M:__init(game, name, visible, options)
    self.game     = game
    self.id       = game:nextId()
    self.name     = name
    self.options  = options or {}
    self.rows     = {}
    self.disabled = {}
    self.markMap  = {}
    if visible == nil then
        visible = true
    end
    self.visible = moe.visibility.normalize(visible)
    self:notifyChange()
end

--- 面板死了：协议侧据此广播移除
function M:__del()
    self.game:fire('面板-变化', self, 'removed')
end

--- 变了就告诉局里（协议侧照它下发；攒到下一笔调度统一发）
function M:notifyChange()
    self.game:fire('面板-变化', self, 'base')
end

--- 追加一行（行序号从 1 起）；返回自己，可以接着链
---@param cards Card[] # 这一行摆的牌（行内有序）
---@param title? string # 给客户端展示的行标题
---@return Panel
function M:row(cards, title)
    self.rows[#self.rows + 1] = { title = title, cards = moe.util.copy(cards) }
    self:notifyChange()
    return self
end

--- 这位牌在面板上吗
---@param card Card
---@return boolean
function M:contains(card)
    for _, row in ipairs(self.rows) do
        for _, one in ipairs(row.cards) do
            if one == card then
                return true
            end
        end
    end
    return false
end

--- 把这位牌从面板上摘下来（不在面板上就是 false）
---@param card Card
---@return boolean
function M:takeOut(card)
    for _, row in ipairs(self.rows) do
        for index, one in ipairs(row.cards) do
            if one == card then
                table.remove(row.cards, index)
                self:notifyChange()
                return true
            end
        end
    end
    return false
end

--- 把一位牌插到第 `row` 行第 `col` 个位置（1 起；`col` 按「先把它从原处摘掉之后」的行算）
--- 不在面板上 / 被禁用 / 行或列不存在 ⇒ 什么都不做
---@param card Card
---@param row integer
---@param col integer
---@return boolean
function M:moveTo(card, row, col)
    local target = self.rows[row]
    if not target or self:isDisabled(card) or not self:contains(card) then
        return false
    end
    local limit = #target.cards + 1
    for _, one in ipairs(target.cards) do
        if one == card then
            limit = limit - 1
            break
        end
    end
    if col < 1 or col > limit then
        return false
    end
    self:takeOut(card)
    table.insert(target.cards, col, card)
    self:notifyChange()
    return true
end

--- 面板上所有牌（按行序）
---@return Card[]
function M:cards()
    ---@type Card[]
    local cards = {}
    for _, row in ipairs(self.rows) do
        for _, one in ipairs(row.cards) do
            cards[#cards + 1] = one
        end
    end
    return cards
end

--- 各行按顺序的牌
---@return Card[][]
M.__getter.cardsByRow = function (self)
    ---@type Card[][]
    local rows = {}
    for _, row in ipairs(self.rows) do
        rows[#rows + 1] = moe.util.copy(row.cards)
    end
    return rows
end

--- 禁用一位牌（**不挪走**：它仍留在行里，只是不能再动、不能再被选）；不在面板上就什么也不做
---@param card Card
---@return boolean # 面板上有没有这张
function M:disableCard(card)
    if not self:contains(card) then
        return false
    end
    self.disabled[card] = true
    self:notifyChange()
    return true
end

--- 这位牌被禁用了吗
---@param card Card
---@return boolean
function M:isDisabled(card)
    return self.disabled[card] == true
end

--- 给一位牌挂一条展示用标记（内容侧定，内核只存）；不在面板上就什么也不做
---@param card Card
---@param text string
function M:addMark(card, text)
    if not self:contains(card) then
        return
    end
    local marks = self.markMap[card]
    if not marks then
        marks = {}
        self.markMap[card] = marks
    end
    marks[#marks + 1] = text
    self:notifyChange()
end

--- 这位牌现在挂着哪些标记
---@param card Card
---@return string[]
function M:marks(card)
    return self.markMap[card] or {}
end

--- 这个视角看得见牌面吗
---@param viewer Player
---@return boolean
function M:isVisibleTo(viewer)
    return moe.visibility.isVisibleTo(self.visible, viewer)
end

---@class Panel.API
moe.panel = {}

---@param game Game
---@param name string
---@param visible Visibility?
---@param options Panel.Options?
---@return Panel
function moe.panel.create(game, name, visible, options)
    return New 'Panel' (game, name, visible, options)
end
