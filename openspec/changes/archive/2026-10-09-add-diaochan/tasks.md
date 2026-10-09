# Tasks

> 本批 = **貂蝉【离间】【闭月】**（用户 2026-10-09 定；「不能被无懈」的字段落点由用户定 = **在【无懈可击】这一包里注入 + 消费**）。**内核一行不改。**

## 1. 「不能被无懈」（内容侧字段）

- [x] 1.1 `package/标准/meta.lua`：注入 `---@class Game.UseOptions` / `Game.UseOptionsInput` 的 `unnullifiable? boolean`（谁读谁注入）
- [x] 1.2 `package/标准/卡牌/无懈可击.lua`：`nullify()` 开头读 `effect.useCard?.useOptions?.unnullifiable` ⇒ 直接不问（`cardTargets` 不用动）

## 2. 内容：貂蝉

- [x] 2.1 新建 `package/标准/武将/貂蝉.lua`：`Hero '貂蝉'`（群 / 女 / 3 体力 / `: skills { '离间', '闭月' }`）+ 文件顶部照 §9.3 写官方描述
- [x] 2.2 【闭月】= `auto(true)` + `event('阶段-开始')`（结束阶段）+ `tryCast` 里 `owner:draw(1)`
- [x] 2.3 【离间】= `limit('出牌', 1)` + `cards { zone = rule.ownZones, min = 1, max = 1 }` + `targets { min = 2, max = 2, filter = 其他男性 }`；`'使用'` 里弃牌 ⇒ 虚拟【决斗】⇒ `useCard(后选者, 决斗, { 先选者 }, { unnullifiable = true })`（`targets[1]` = 挨打的）

## 3. 用例

- [x] 3.1 `rule.trick` +1：这次使用声明了 `unnullifiable` ⇒ 无懈**连问都不问**、锦囊照常生效、手里的无懈没动
- [x] 3.2 `rule.hero-skill` +4：闭月默认不问就摸一张 / 关掉自动同意会问、答否不摸 / 离间弃牌 + 决斗方向（响应问的是先选那位、先选挨 1 点）+ **没人被问无懈** / 候选只有其他男性 + 限一次
- [x] 3.3 全量 `server/bin/moe-kill.exe --test` 0 失败（报出基线数：986 → 991）

## 4. 验收与文档

- [x] 4.1 `sanguosha-rules`：§9.10 无懈条目补「`unnullifiable` 住内容侧」；新增 **§9.26 貂蝉【离间】【闭月】**（含「目标顺序首次当语义」这条）
- [x] 4.2 `moe-kill-dev/references/architecture.md`：`Game.UseOptions` 行补「**内容侧可以自己定字段名**（首个例子 = 【无懈可击】的 `unnullifiable`）」
- [x] 4.3 `moe-kill-dev/references/progress.md`：§1 记账 + 基线 991；§2 武将表（貂蝉落地、「已落地 19 将」）与缺口表（「不能被无懈」已补）
- [x] 4.4 收尾清单过一遍：问题面板 information 及以上 0（改完 `lua.startServer` 重启后再看）、硬约束自查、停在待确认状态
