# Tasks

## 1. 时机（@基础）

- [x] 1.1 `package/@基础/伤害.lua`：`Damage:settle()` 在扣体力之前发 `'伤害-开始'`（全局）+ `'伤害-来源-开始'`（对 `damage.from`，没有来源不发）—— 以 3.1 验证
- [x] 1.2 `package/@基础/meta.lua`：补 `Game` / `Player` 两条类型声明 —— 以 1.1 的发出点与 2.1 的订阅点面板无报错验证

## 2. 麒麟弓

- [x] 2.1 `package/标准/卡牌/麒麟弓.lua`：『被动』订 `owner:on('伤害-来源-开始')`（渠道是本人用的【杀】+ 打的是那张杀的目标；有坐骑才问、不答不发动）—— 以 3.2 / 3.3 验证

## 3. 用例

- [x] 3.1 `server/test/core/effect/damage.lua`：新时机两条（扣血前发、全局先来源后；无来源只发全局那份）—— `--test core.effect.damage` 全绿
- [x] 3.2 `server/test/rule/equip.lua` 麒麟弓一组：正例（询问时点未扣血、候选只有坐骑、弃的进弃牌堆、修正回落、照常掉血）—— `--test rule.equip` 全绿
- [x] 3.3 条件不满足一组：不答 / 目标没坐骑 /【决斗】的伤害 / 旁人用【杀】/ 拆下武器 —— `--test rule.equip` 全绿
- [x] 3.4 全量回归：`server/bin/moe-kill.exe --test` 0 失败（记录新基线）

## 4. 收尾

- [x] 4.1 问题面板：information 及以上清到 0（伤害 / meta / 麒麟弓 / 用例）
- [x] 4.2 文档：`sanguosha-rules` §7（伤害时机说明）+ §9.11（麒麟弓移出「还没做」）；`progress.md`（本批记录与基线）
- [x] 4.3 `openspec validate add-qilin-bow --strict` 通过；勾选全部 tasks 后 `openspec archive add-qilin-bow --yes`
