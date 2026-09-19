---@meta

---@type Moe.Rule.InGame
rule = nil

---@class Moe.Rule.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 rule.room 取

---@class Moe.Rule
---@field on fun(self: Moe.Rule, name: '游戏-开始', callback: fun(ctx: Moe.Rule.EventCtx.游戏开始)): function
---@field fire fun(self: Moe.Rule, name: '游戏-开始', ctx: Moe.Rule.EventCtx.游戏开始)
---@field on fun(self: Moe.Rule, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Moe.Rule, name: string, ...: any)

---@class Moe.Rule.InGame : Moe.Rule
---@field room Moe.Room # 规则包拿到的实例一定由场地建出来，所以这个字段必填
