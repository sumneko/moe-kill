---@meta

---@type Moe.Rule
rule = nil

---@class Moe.Rule.EventCtx.游戏开始
---@field desk Moe.Desk
---@field random Moe.Random
---@field room Moe.Room

---@class Moe.Rule
---@field on fun(self: Moe.Rule, name: '游戏-开始', callback: fun(ctx: Moe.Rule.EventCtx.游戏开始)): function
---@field fire fun(self: Moe.Rule, name: '游戏-开始', ctx: Moe.Rule.EventCtx.游戏开始)
---@field on fun(self: Moe.Rule, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Moe.Rule, name: string, ...: any)
