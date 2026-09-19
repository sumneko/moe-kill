---@meta

---@type Rule
rule = nil

---@type Core
core = nil

---@class Rule.EventCtx.游戏开始
---@field desk Core.Desk
---@field random Core.Random

---@class Rule
---@field on fun(self: Rule, name: '游戏-开始', callback: fun(ctx: Rule.EventCtx.游戏开始)): function
---@field fire fun(self: Rule, name: '游戏-开始', ctx: Rule.EventCtx.游戏开始)
---@field on fun(self: Rule, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Rule, name: string, ...: any)
