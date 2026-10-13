--- 面板下行：内核只说「哪块面板变了」，这里按各人视角拼好发下去（创建发整块、以后只发增量）；另接客户端的挪牌请求
--- 面板创建出来就发给所有人（此后只是展示）—— 要操作得等一次 `askPanel` 把它「开着」

---@class PanelSync.API
moe.panelSync = {}

--- 客户端接入了：把这一局的面板下行账带起来（重复调无害）
---@param user User
---@return Game.PanelSync
function moe.panelSync.attach(user)
    return user.game.panelSync
end

--- 记下「这块面板正开着询问」（返回撤销函数 —— 本次请求挂着期间有效）
---@param ask AskPanel
---@return fun()
function moe.panelSync.open(ask)
    return ask.game.panelSync:open(ask)
end

--- 这块面板现在开着询问吗（开着才允许操作）
---@param game Game
---@param id integer
---@return AskPanel?
function moe.panelSync.opened(game, id)
    return game.panelSync.opened[id]
end

--- 一块面板「上次发出去的样子」（都以 `Card` 记 —— 号是按各人视图现算的）
---@class Game.PanelSync.Sent
---@field rows Card[][]
---@field disabled table<Card, true>
---@field marks table<Card, string[]>

--- 两次样子之间变了什么
---@class Game.PanelSync.Delta
---@field rows { row: integer, cards: Card[] }[] # 变了的那些行（完整新状态）
---@field disabled Card[] # 新被禁用的
---@field enabled Card[] # 被恢复的
---@field addMark { card: Card, mark: string }[]
---@field removeMark { card: Card, mark: string }[]

--- 一块面板现在的样子
---@param panel Panel
---@return Game.PanelSync.Sent
local function snapshotOf(panel)
    ---@type Card[][]
    local rows = {}
    for _, row in ipairs(panel.rows) do
        rows[#rows + 1] = moe.util.copy(row.cards)
    end
    ---@type table<Card, true>
    local disabled = {}
    ---@type table<Card, string[]>
    local marks = {}
    for _, card in ipairs(panel:cards()) do
        if panel:isDisabled(card) then
            disabled[card] = true
        end
        local list = panel:marks(card)
        if #list > 0 then
            marks[card] = list
        end
    end
    return { rows = rows, disabled = disabled, marks = marks }
end

--- 两条牌表按顺序一样吗
---@param a Card[]
---@param b Card[]
---@return boolean
local function sameCards(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

--- 两次标记的差（按条数，不按顺序 —— 标记是加的，多半是前缀）
---@param before string[]
---@param now string[]
---@return string[] # 新挂上的
---@return string[] # 被摘掉的
local function diffMarks(before, now)
    ---@type table<string, integer>
    local count = {}
    for _, text in ipairs(before) do
        count[text] = (count[text] or 0) + 1
    end
    ---@type string[]
    local added = {}
    for _, text in ipairs(now) do
        local left = count[text] or 0
        if left > 0 then
            count[text] = left - 1
        else
            added[#added + 1] = text
        end
    end
    ---@type string[]
    local removed = {}
    for text, left in pairs(count) do
        for _ = 1, left do
            removed[#removed + 1] = text
        end
    end
    table.sort(removed)
    return added, removed
end

--- 这块面板从 `before` 到 `now` 变了什么
---@param before Game.PanelSync.Sent
---@param now Game.PanelSync.Sent
---@return Game.PanelSync.Delta
local function deltaOf(before, now)
    ---@type Game.PanelSync.Delta
    local delta = { rows = {}, disabled = {}, enabled = {}, addMark = {}, removeMark = {} }
    for index = 1, math.max(#before.rows, #now.rows) do
        local old = before.rows[index]
        local new = now.rows[index]
        if not old or not new or not sameCards(old, new) then
            delta.rows[#delta.rows + 1] = { row = index, cards = new or {} }
        end
    end
    for _, row in ipairs(now.rows) do
        for _, card in ipairs(row) do
            if now.disabled[card] and not before.disabled[card] then
                delta.disabled[#delta.disabled + 1] = card
            elseif before.disabled[card] and not now.disabled[card] then
                delta.enabled[#delta.enabled + 1] = card
            end
            local added, removed = diffMarks(before.marks[card] or {}, now.marks[card] or {})
            for _, text in ipairs(added) do
                delta.addMark[#delta.addMark + 1] = { card = card, mark = text }
            end
            for _, text in ipairs(removed) do
                delta.removeMark[#delta.removeMark + 1] = { card = card, mark = text }
            end
        end
    end
    return delta
end

--- 一块面板的整块形状（创建时发）
---@param user ClientUser
---@param panel Panel
---@return Proto.Panel
function moe.panelSync.toProto(user, panel)
    local view = user.cardView
    ---@type Proto.PanelRow[]
    local rows = {}
    for _, row in ipairs(panel.rows) do
        rows[#rows + 1] = { title = row.title, cards = user:cardIds(row.cards) }
    end
    ---@type integer[]
    local disabled = {}
    ---@type Proto.PanelMark[]
    local marks = {}
    for _, card in ipairs(panel:cards()) do
        local id = view.cardMap[card].id
        if panel:isDisabled(card) then
            disabled[#disabled + 1] = id
        end
        for _, text in ipairs(panel:marks(card)) do
            marks[#marks + 1] = { card = id, mark = text }
        end
    end
    return {
        id       = panel.id,
        name     = panel.name,
        moveable = panel.options.moveable == true,
        min      = panel.options.min or 0,
        max      = panel.options.max or panel.options.min or 0,
        rows     = rows,
        disabled = disabled,
        marks    = marks,
    }
end

--- 一块面板的增量（更新时发）
---@param user ClientUser
---@param panel Panel
---@param delta Game.PanelSync.Delta
---@return Proto.PanelUpdate
local function toUpdate(user, panel, delta)
    local view = user.cardView
    ---@type Proto.PanelUpdate
    local update = { id = panel.id }
    if #delta.rows > 0 then
        ---@type Proto.PanelRowUpdate[]
        local rows = {}
        for _, item in ipairs(delta.rows) do
            rows[#rows + 1] = { row = item.row, cards = user:cardIds(item.cards) }
        end
        update.rows = rows
    end
    if #delta.disabled > 0 then
        update.disabled = user:cardIds(delta.disabled)
    end
    if #delta.enabled > 0 then
        update.enabled = user:cardIds(delta.enabled)
    end
    if #delta.addMark > 0 then
        ---@type Proto.PanelMark[]
        local list = {}
        for _, item in ipairs(delta.addMark) do
            list[#list + 1] = { card = view.cardMap[item.card].id, mark = item.mark }
        end
        update.addMark = list
    end
    if #delta.removeMark > 0 then
        ---@type Proto.PanelMark[]
        local list = {}
        for _, item in ipairs(delta.removeMark) do
            list[#list + 1] = { card = view.cardMap[item.card].id, mark = item.mark }
        end
        update.removeMark = list
    end
    return update
end

---@class Game: Class.Base
---@field package panelSync Game.PanelSync # 这一局的面板下行账本
local Game = Class 'Game'

---@param self Game
---@return Game.PanelSync
---@return true
Game.__getter.panelSync = function (self)
    return New 'Game.PanelSync' (self), true
end

--- 按局的账本挂在局上：`package` 可见性只给本文件看（内核不认识协议，就不写进 game.lua 了）
---@class Game.PanelSync
---@field opened table<integer, AskPanel> # 正开着询问的面板（面板号 → 那次询问）
---@field broadcasted table<integer, true> # 已经下发过创建的面板号（之后发的是增量）
---@field sent table<Panel, Game.PanelSync.Sent> # 上次发出去的样子（弱键：别把面板栓住）
---@field dirty? table<Panel, true> # 还没下发的脏面板（下一笔调度统一发）
---@field removed? integer[] # 已经拆掉、还没广播移除的面板号
local S = Class 'Game.PanelSync'

---@param game Game
function S:__init(game)
    self.game        = game
    self.opened      = {}
    self.broadcasted = {}
    ---@type table<Panel, Game.PanelSync.Sent>
    self.sent        = setmetatable({}, { __mode = 'k' })

    game:on('面板-变化', function (panel, kind)
        self:markDirty(panel, kind)
    end)
end

---@param panel Panel
---@param kind Panel.DirtyKind
function S:markDirty(panel, kind)
    if kind == 'removed' then
        self.opened[panel.id]      = nil
        self.broadcasted[panel.id] = nil
        local removed = self.removed
        if not removed then
            removed = {}
            self.removed = removed
        end
        removed[#removed + 1] = panel.id
    else
        local dirty = self.dirty
        if not dirty then
            dirty = {}
            self.dirty = dirty
        end
        dirty[panel] = true
    end
    if not self.pending then
        self.pending = true
        moe.await.wake(function ()
            self.pending = false
            self:flush()
        end)
    end
end

--- 把攒着的脏面板发下去（第一次发整块，以后只发增量；各人按自己的牌视图发号）
function S:flush()
    local dirty   = self.dirty
    local removed = self.removed
    if not dirty and not removed then
        return
    end
    self.dirty   = nil
    self.removed = nil

    ---@type Panel[] # 第一次发 → 整块
    local created = {}
    ---@type { panel: Panel, delta: Game.PanelSync.Delta }[] # 以后发 → 增量
    local updated = {}
    for panel in pairs(dirty or {}) do
        local before = self.sent[panel]
        local now    = snapshotOf(panel)
        self.sent[panel] = now
        if before and self.broadcasted[panel.id] then
            updated[#updated + 1] = { panel = panel, delta = deltaOf(before, now) }
        else
            created[#created + 1] = panel
            self.broadcasted[panel.id] = true
        end
    end

    for _, player in ipairs(self.game.desk.players) do
        local user = player.user
        if user then
            ---@cast user ClientUser
            if removed then
                for _, id in ipairs(removed) do
                    ---@type Proto.Notify.Panel.Remove
                    local data = { id = id }
                    user:notify('Panel.Remove', data)
                end
            end
            for _, panel in ipairs(created) do
                ---@type Proto.Notify.Panel.Create
                local data = { panel = moe.panelSync.toProto(user, panel) }
                user:notify('Panel.Create', data)
            end
            for _, item in ipairs(updated) do
                ---@type Proto.Notify.Panel.Update
                local data = { panel = toUpdate(user, item.panel, item.delta) }
                user:notify('Panel.Update', data)
            end
        end
    end
end

---@param ask AskPanel
---@return fun()
function S:open(ask)
    local id = ask.panel.id
    self.opened[id] = ask
    return function ()
        if self.opened[id] == ask then
            self.opened[id] = nil
        end
    end
end

--- 这条请求现在做不了：把原因回给客户端（处理器第二返回值 = `Proto.Error`）
---@param code integer
---@param message string
---@return nil
---@return Proto.Error
local function rejected(code, message)
    return nil, { code = code, message = message }
end

moe.client.register('Panel.Move', function (client, params)
    ---@cast params Proto.Request.Panel.Move
    local game = moe.snapshot._game
    if not game then
        return rejected(moe.jsonrpc.INVALID_REQUEST, '还没开局')
    end
    local user = moe.snapshot.userOf(game, client)
    if not user then
        return rejected(moe.jsonrpc.INVALID_REQUEST, '这条连接还没入座')
    end
    ---@cast user ClientUser
    local ask = moe.panelSync.opened(game, params.id)
    if not ask then
        return rejected(moe.jsonrpc.INVALID_REQUEST, '这块面板现在没开着询问')
    end
    if ask.to ~= user.player then
        return rejected(moe.jsonrpc.INVALID_REQUEST, '这块面板不是问他的')
    end

    local card = user.cardView:cardOf(params.card)
    if not card then
        return rejected(moe.jsonrpc.INVALID_PARAMS, '认不出这张牌')
    end

    local problem = ask:applyChange { moves = { { card = card, row = params.row, col = params.col } } }
    ---@type Proto.Result.Panel.Move
    local result = { success = problem == nil }
    return result
end)
