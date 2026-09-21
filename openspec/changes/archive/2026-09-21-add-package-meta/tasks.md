# Tasks

## 1. 三个包各补一份 `meta.lua`（纯类型，运行期零变化）

- [x] 1.1 `package/@基础/meta.lua`：`getValue` 收窄 `默认体力` / `主公额外体力` → `integer`；`getAttr` / `setAttr` / `addAttr` 收窄 `体力` / `体力上限` / `攻击范围` → `number`；每条都带 `string` 兜底
- [x] 1.2 `package/身份场/meta.lua`：`---@alias 身份场.身份`（主公 / 忠臣 / 反贼 / 内奸）+ `身份场.身份配置` 结构 + `Player:getTag` / `setTag` 的 `'身份'` 收窄
- [x] 1.3 `package/标准/meta.lua`：`牌表` 收窄成 `{ name: string, count: integer }[]`
- [x] 1.4 验证：全量 `--test` 0 失败（文件只有注释 ⇒ 装载它不该有任何副作用）

## 2. 用例（锁住「meta 文件是普通文件」这个决定）

- [x] 2.1 `server/test/rule/meta.lua` 补一条：包里放一个 `meta.lua`（纯类型注释）时，照常参与装载（出现在执行过的文件名单里）、不报错，且**不进规则表**（`game:getCard('甲.占位')` 拿到 `nil`，同包的正常文件照常登记）
- [x] 2.2 验证：`--test rule.meta` 全绿

## 3. 验证类型收窄真的生效

- [x] 3.1 hover 抽查三处：`player:getTag('身份')`、`game:getValue('主公额外体力')`（**跨包**：在 `身份场/开局.lua` 里读 `@基础` 的值）、`player:getAttr('体力')`
- [x] 3.2 问题面板 information 及以上为 0（**关键回归**：写收窄时漏了兜底签名会让全仓 27 处报错）

## 4. 文档

- [x] 4.1 `architecture.md`：新增「包自带 `meta.lua`」的约定与配方（含「兜底必须自己再写一遍」的坑），并把「类型面只有 `env-meta.lua`」改成两处（内核通用面 + 各包自己的概念）
- [x] 4.2 `sanguosha-rules` §9.1 补一条：包里可带 `meta.lua` 做类型收窄（附最小示例）
- [x] 4.3 `code-style.md`：记下「跨文件重声明同名 `---@field` 会接管签名表 ⇒ 必须带兜底」
- [x] 4.4 `moe-kill-dev/SKILL.md` 的 `package/` 行补一句「可以带 `meta.lua`（纯类型）」
