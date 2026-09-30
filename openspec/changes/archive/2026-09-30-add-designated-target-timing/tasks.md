# Tasks

## 1. 内核

- [x] 1.1 `server/core/effect/use-card.lua`：加逐目标「指定目标后」（`actionOrder`、每目标三份、在 `'使用'` 钩子之前；`skipEffect` 照发）—— 以 3.1 / 3.2 验证
- [x] 1.2 `server/core/loader/env-meta.lua`：`Game` 的 `'卡牌-指定目标后'` + `Player` 的 `'卡牌-来源-指定目标后'` / `'卡牌-目标-指定目标后'` 声明（载荷 `(useCard, target)`）—— 以 4.1 面板无报错验证

## 2. 内容

- [x] 2.1 `package/标准/卡牌/青釭剑.lua`：迁到逐目标的 `'卡牌-来源-指定目标后'`（逐目标压 buff）—— 以 3.3 验证
- [x] 2.2 `package/标准/卡牌/雌雄双股剑.lua`：迁过去、去掉自循环（`for` / `goto continue` → 处理单个目标）—— 以 3.3 验证

## 3. 用例

- [x] 3.1 `server/test/core/effect/play.lua`：+1「指定目标后逐目标发三份」；skipEffect 用例补断言（照发三份）—— `--test core.effect.play` 全绿
- [x] 3.2 `server/test/core/effect/play.lua`：既有 `'卡牌-结算前'` 用例不动（该时机保留）
- [x] 3.3 `server/test/rule/equip.lua`：青釭两处模拟订阅改订 `'卡牌-来源-指定目标后'`（注册在青釭之后）—— `--test rule.equip` 全绿
- [x] 3.4 全量回归：0 失败（记录新基线）

## 4. 收尾

- [x] 4.1 问题面板 information 及以上 0
- [x] 4.2 文档：`architecture.md` / `sanguosha-rules` §9.11 / `progress.md` / `HANDOVER.md`
- [x] 4.3 `openspec validate add-designated-target-timing --strict` 通过；勾选全部 tasks 后 `openspec archive add-designated-target-timing --yes`
