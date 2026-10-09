# Tasks

## 1. 内核：区域事件对区的主人再发一份

- [x] 1.1 `server/core/zone.lua`：`notifyEnter` / `notifyLeave` 在跑完牌自己那份之后 `self.owner?:fire('卡牌-进入区域' / '卡牌-离开区域', card, self)`（顺序：牌自己 → 区主人；压制那层的位置不变）
- [x] 1.2 `server/core/loader/env-meta.lua`：`Player` 块补 `on` / `fire` 的 `'卡牌-进入区域'` / `'卡牌-离开区域'`（载荷 `(card, zone)`），`SkillDef` 块补两条 `event` 候选

## 2. 内容：孙尚香

- [x] 2.1 `package/标准/武将/孙尚香.lua`（新）：吴 · 女 · 体力上限 3；【枭姬】`event('卡牌-离开区域')` + `auto(true)` + `owner:draw(2)`；【结姻】`limit('出牌', 1)` + 两张手牌 + 目标过滤 + 双方各回复 1 点

## 3. 用例

- [x] 3.1 `server/test/core/zone.lua`：区域事件对区的主人再发一份（牌自己那份在前、主人那份在后；公共区没有主人 ⇒ 不发；旁人收不到）
- [x] 3.2 `server/test/rule/hero-skill.lua`：【枭姬】3 条（拆装备摸两张 / 换装也算 / 手牌离开与别人的装备离开都不摸）
- [x] 3.3 `server/test/rule/hero-skill.lua`：【结姻】2 条（弃两张 + 受伤男性 ⇒ 双方各回 1 点且限一次 / 候选只有已受伤的其他男性）

## 4. 文档

- [x] 4.1 `sanguosha-rules`：§9.2 区域事件条目补「对区的主人再发一份」；新增 §9.27 孙尚香（【枭姬】【结姻】口径）
- [x] 4.2 `moe-kill-dev/references/architecture.md`：区域事件行（两份、顺序）+ 「同名两份」名单加 `'卡牌-进入区域'` / `'卡牌-离开区域'`
- [x] 4.3 `moe-kill-dev/references/progress.md`：基线 997、武将表、缺口表（「玩家级『牌离开某个区』事件」已补）

## 5. 收尾

- [x] 5.1 `server/bin/moe-kill.exe --test` 全绿（997 用例 0 失败）
- [x] 5.2 问题面板 information 及以上 0
- [x] 5.3 同日改名（用户提「不符合项目习惯」）：`'进入区域'` / `'离开区域'` → **`'卡牌-进入区域'` / `'卡牌-离开区域'`**（对齐「分类-动作」命名）—— 内核 / `env-meta` / 内容侧 / 用例 / 文档全同步，997 用例照旧全绿
