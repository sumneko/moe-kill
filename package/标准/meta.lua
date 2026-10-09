---@meta

--- 一张牌一条（逐张：同名多张各有各的花色与点数）
---@class 标准.牌表项
---@field name string
---@field suit string # 花色：黑桃 / 红桃 / 梅花 / 方块
---@field point integer # 点数：1..13（A=1 … K=13）

--- 牌表挂在装载器给的共享袋上（标准包提供；别的包可以整张换掉）
---@class Loader.Rule
---@field cardTable? 标准.牌表项[]

--- 【无懈可击】自己认的「使用选项」字段：这次使用不能被无懈（内核不预设选项名 ⇒ 谁读谁注入）
---@class Game.UseOptions
---@field unnullifiable? boolean
---@class Game.UseOptionsInput
---@field unnullifiable? boolean
