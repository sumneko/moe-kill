# Tasks

## 1 装载器：白名单里表值的项改成副本

- [x] 1.1 `server/core/loader/init.lua` 的 `makeEnv`：`type(value) == 'table'` 的项浅拷贝一份再进 `env`（不手写名单，覆盖 `table` / `string` / `math` / `utf8`）
- [x] 1.2 不加元表 / 代理（实测一层拷贝即够）；`ctx.env` 每轮 install 建一次 ⇒ 副本随重装更新
- [x] 1.3 试跑那趟（`probeEnv`）走同一个 `makeEnv` ⇒ 语义一致，无需额外改动

## 2 工具包：挂到内容侧的 `table` 上

- [x] 2.1 `package/@tools/table.lua`：`table.filter` / `table.map` / `table.contains`，内容侧写法（只用 `#` 与下标，不借内核 `moe.util`）
- [x] 2.2 类型写在赋值处：`---@generic T` / `---@generic T, U` 标在**实体函数**上；`map` 回调收 `(value, index)`、`index` 用 `integer`
- [x] 2.3 删掉 `package/@tools/工具.lua` 与 `package/@tools/meta.lua`（用户决定；类型已能写在赋值处）
- [x] 2.4 `package/标准/卡牌/杀.lua` 的「获取目标」改用 `table.filter`

## 3 用例

- [x] 3.1 改写「工具集可用」：内容侧直接 `table.filter` / `table.map` / `table.contains`，来源含真 `./package/*`
- [x] 3.2 新增「内容侧的标准库是副本，改了不影响内核」：内容侧加 `table.乱来` 读得到，内核侧 `rawget(table, '乱来')` 仍是 `nil`
- [x] 3.3 `--test rule` 与全量 `--test` 全绿（358 用例 0 失败）
- [x] 3.4 问题面板 information 及以上 0（含把断言写成 `rawget` 以避开 `undefined-field`）

## 4 文档

- [x] 4.1 `architecture.md` §9.6：「白名单里表值的项是内容侧的副本」+ 工具集改成「对（内容侧）标准库的扩充」（代价改成「没装 `@tools` 仍有 `table`，只是没有三个助手」）；沙箱那条括注四个表值是副本
- [x] 4.2 `architecture.md` 泛型那条：补「给标准库补字段也一样（`function table.filter(…)` 才带 `<T>`)」，证据换成 hover 结果
- [x] 4.3 `architecture.md` 类型面那条 + 「常用动作的形状」示例改成 `table.filter`
- [x] 4.4 `sanguosha-rules/SKILL.md` §9.1：「工具集是对（内容侧）标准库的扩充」+「内容侧的标准库是副本」两条取代旧的 `Table` 两条；共享函数那条与「不需要 `require`」那条同步；示例改 `table.filter`
- [x] 4.5 `moe-kill-dev/SKILL.md` 的 `package/` 行：`@tools` 改述为「扩充内容侧的标准库」
- [x] 4.6 全仓 grep 确认无残留 `Table.` / `工具.lua` 口径（归档目录里的历史记录不动）

## 5 归档

- [x] 5.1 `openspec validate extend-content-stdlib`（探索期零增量，接受 INFO）
- [x] 5.2 `openspec archive extend-content-stdlib --yes`
- [x] 5.3 提交（`【AI】` 前缀；连同用户此前的改名一起）
