# Tasks

## 1. 内核

- [x] 1.1 `server/core/loader/init.lua`：这一轮建的共享袋同时挂到 `game.rule`
- [x] 1.2 `server/core/game.lua`：`resetContent` 里 `self.rule = {}`
- [x] 1.3 `server/core/loader/env-meta.lua`：`Game` 补 `rule` 与通用 `setValue` / `setValues` / `getValue` / `getValues`

## 2. 内容：写点

- [x] 2.1 `@基础/配置.lua`：`rule.defaultHp` / `rule.lordHpBonus` / `rule.defaultDrawCount`
- [x] 2.2 `@基础/回合.lua`：`local PHASES` → `rule.phases`
- [x] 2.3 `标准/牌表.lua`：`rule.cardTable`
- [x] 2.4 `身份场/配置.lua`：`rule.heroCandidateCount` / `rule.identityConfig`

## 3. 内容：读点

- [x] 3.1 `@基础/牌堆.lua` / `@基础/阶段/摸牌阶段.lua` / `@基础/体力.lua` / `@基础/武将.lua`
- [x] 3.2 `身份场/开局.lua` / `身份场/选将.lua`

## 4. 类型

- [x] 4.1 `@基础/meta.lua` / `标准/meta.lua` / `身份场/meta.lua`：具名重载 → `Loader.Rule` 的 `---@field`（可空）

## 5. 用例

- [x] 5.1 `rule/base.lua`（覆盖 / 清空 / 牌表张数）+ 新增「换掉共享袋里的表就按新的走」
- [x] 5.2 `rule/turn.lua` 新增「阶段清单从共享袋里读」；`rule/identity.lua` / `rule/equip.lua` / `core/game.lua` / `core/reload.lua` 跟着改

## 6. 收尾

- [x] 6.1 测试全绿（**1109**）
- [x] 6.2 问题面板 information 及以上 0
- [x] 6.3 反向验证（已填进 `design.md` D5）
- [x] 6.4 `openspec validate --all --strict`
- [x] 6.5 文档同步（`architecture.md` §9.7 重写 / `sanguosha-rules` / `progress.md` / `code-style.md` 命名表）
- [x] 6.6 停在待确认状态，等「提交」
