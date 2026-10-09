--- 面板：把一批牌摊成若干行，可以在上面「选择 / 移动」，可以标记与禁用
--- 牌仍住在区里 —— 面板是「布局 + 交互状态」的视图，不负责搬牌（搬牌照旧 `placeTop` / `moveCard`）
---@class Panel : GCHost, Class.Base
---@field name string # 这块面板叫什么（内容侧定，原样带到应答方）
---@field rows Panel.Row[] # 各行（`rows[1]` 是 1 号行；协议里就用行序号）
---@field cardsByRow Card[][] # 各行按顺序的牌（就是询问结果里 `rows` 那个形状）
---@field options Panel.Options # 选项（服务器不解释语义，只照它校验）
---@field private game Game
---@field private visible Visibility # 牌面的可见性（帮不上忙的就是背面朝上；**面板本身人人可见**：几行、每行几张都看得见）
local M = Class 'Panel'

Extends('Panel', 'GCHost')

--- 面板上的一格：一位牌 + 它的展示状态
---@class Panel.Cell
---@field card Card
---@field disabled? boolean # 被禁用了（不能再动、不能再被选；仍留在行里）
---@field marks? string[] # 展示用标记（内容侧定，内核只存）

--- 面板上的一行（行内有序；标题只给客户端排版用）
---@class Panel.Row
---@field title? string
---@field cells Panel.Cell[]

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
    self.game    = game
    self.name    = name
    self.options = options or {}
    self.rows    = {}
    if visible == nil then
        visible = true
    end
    self.visible = moe.visibility.normalize(visible)
end

--- 追加一行（行序号从 1 起）；返回自己，可以接着链
---@param cards Card[] # 这一行摆的牌（行内有序）
---@param title? string # 给客户端展示的行标题
---@return Panel
function M:row(cards, title)
    ---@type Panel.Cell[]
    local cells = {}
    for _, card in ipairs(cards) do
        cells[#cells + 1] = { card = card }
    end
    self.rows[#self.rows + 1] = { title = title, cells = cells }
    return self
end

--- 找一位牌在哪一格（不在面板上就是空）
---@param card Card
---@return Panel.Cell?
function M:findCell(card)
    for _, row in ipairs(self.rows) do
        for _, cell in ipairs(row.cells) do
            if cell.card == card then
                return cell
            end
        end
    end
    return nil
end

--- 这位牌在面板上吗
---@param card Card
---@return boolean
function M:contains(card)
    return self:findCell(card) ~= nil
end

--- 把这位牌从面板上摘下来（它那一格照旧带着状态；不在就是空）
---@param card Card
---@return Panel.Cell?
function M:takeOut(card)
    for _, row in ipairs(self.rows) do
        for index, cell in ipairs(row.cells) do
            if cell.card == card then
                table.remove(row.cells, index)
                return cell
            end
        end
    end
    return nil
end

--- 把一格放到某一行末尾
---@param row Panel.Row
---@param cell Panel.Cell
function M:appendCell(row, cell)
    row.cells[#row.cells + 1] = cell
end

--- 面板上所有牌（按行序）
---@return Card[]
function M:cards()
    ---@type Card[]
    local cards = {}
    for _, row in ipairs(self.rows) do
        for _, cell in ipairs(row.cells) do
            cards[#cards + 1] = cell.card
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
        ---@type Card[]
        local cards = {}
        for _, cell in ipairs(row.cells) do
            cards[#cards + 1] = cell.card
        end
        rows[#rows + 1] = cards
    end
    return rows
end

--- 禁用一位牌（**不挪走**：它仍留在行里，只是不能再动、不能再被选）；不在面板上就什么也不做
---@param card Card
---@return boolean # 面板上有没有这张
function M:disableCard(card)
    local cell = self:findCell(card)
    if not cell then
        return false
    end
    cell.disabled = true
    return true
end

--- 这位牌被禁用了吗
---@param card Card
---@return boolean
function M:isDisabled(card)
    return self:findCell(card)?.disabled == true
end

--- 给一位牌挂一条展示用标记（内容侧定，内核只存）；不在面板上就什么也不做
---@param card Card
---@param text string
function M:addMark(card, text)
    local cell = self:findCell(card)
    if not cell then
        return
    end
    cell.marks = cell.marks or {}
    cell.marks[#cell.marks + 1] = text
end

--- 这位牌现在挂着哪些标记
---@param card Card
---@return string[]
function M:marks(card)
    return self:findCell(card)?.marks or {}
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
