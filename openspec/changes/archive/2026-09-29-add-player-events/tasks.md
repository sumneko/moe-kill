# 任务

## 1 内核

- [x] 1.1 `server/core/player.lua`：时机表（`__init` 建 `Event` + `on / fire / collect`）
- [x] 1.2 `server/core/effect/effect.lua`：`from?` / `to?` 注解 + `fireVeto` + `apply()` 三段式
- [x] 1.3 `server/core/effect/use-card.lua`：`CardEffect.from / .to`、`UseCard.from`（`__getter` 转发）
- [x] 1.4 `server/core/effect/use-card-to-card.lua`：`UseCardToCard.from`、`CardEffectToCard.from`

## 2 内容

- [x] 2.1 `package/标准/卡牌/仁王盾.lua`：迁到 `owner:on('效果-目标-能否生效')`

## 3 用例

- [x] 3.1 `server/test/core/player.lua`：玩家级时机表（转发、disposer、与别人隔离）
- [x] 3.2 `server/test/core/effect/init.lua`：三段式（顺序、短路、无来源 / 无玩家相关跳过、目标段 false 归一、玩家隔离）
- [x] 3.3 `server/test/rule/equip.lua`：仁王盾回归（既有 3 条）
- [x] 3.4 全量回归 + 问题面板清零

## 4 收尾

- [x] 4.1 文档（`architecture.md`、`sanguosha-rules` §9.11、`env-meta.lua` 声明、`progress.md`）
- [x] 4.2 `openspec validate add-player-events --strict` + 归档
