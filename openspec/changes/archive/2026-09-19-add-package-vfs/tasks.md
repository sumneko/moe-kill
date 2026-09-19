# Tasks

## 1. 虚拟文件系统（`server/rule/vfs.lua`）

- [x] 1.1 来源解析：`X` 与结尾 `/*` 两种写法 → 展开成 `(逻辑包目录名, 物理目录)` 列表；非法写法（`X/*.lua`、`X/*/y`、中间 `*`）明确报错；验证：`--test rule.vfs` 能跑出用例，两种写法都得到预期的逻辑路径
- [x] 1.2 合并逻辑树：按来源顺序建「逻辑路径 → 物理路径」表（后写覆盖先写），目录列举为跨来源合并（递归、只取 `.lua`、排序）；验证：覆盖与并集用例通过
- [x] 1.3 对外接口：`exists` / `read` / `listFiles` / `resolve`；默认来源 `{ './package/*' }`（基准 = 仓库根）；来源路径不存在 → 报错，`X/*` 匹配 0 个 → 允许；验证：对应用例通过
- [x] 1.4 不缓存：每次合并当场重扫；验证：同一来源两次加载之间替换文件，第二次看到新内容

## 2. 加载器接入

- [x] 2.1 `server/rule/init.lua` 的 `loadItem` 改走 vfs（判定顺序：文件 → 补 `.lua` 的文件 → 目录），`loadDirectory` 改走 `vfs:listFiles`；验证：`--test rule` 全绿
- [x] 2.2 新增 `M.setRoots(sources)`（`setRoot` 保留为单来源简写），默认来源 `{ './package/*' }`；验证：默认来源与显式来源的用例都通过
- [x] 2.3 同一逻辑路径在两个来源里都有时只执行生效版本；验证：该用例通过

## 3. 相对路径依赖

- [x] 3.1 `rule.depends` 的项以 `.` / `..` 开头时按声明它的文件所在目录解析，并在逻辑路径层面归一化（`a/../b` → `b`）；验证：相对依赖用例通过，且同一文件两种写法只执行一次
- [x] 3.2 非相对依赖仍按逻辑根解析（既有写法不变）；验证：既有依赖用例继续通过

## 4. 改名与文案

- [x] 4.1 代码与文档里的 `game/` 引用改为 `package/`（`server/rule/init.lua` 默认值、技能文档、示例）；协议域前缀 `game/` 不动；验证：`grep -ri "game/"` 的剩余命中只有协议域与历史归档
- [x] 4.2 直接改主规格 `openspec/specs/rule-loading/spec.md` 与 `openspec/specs/chinese-identifier/spec.md` 的 `## Purpose` 文案（`game/` → `package/`）；验证：两个主规格读起来自洽（delta 不能改 Purpose，故直接改）

## 5. 测试

- [x] 5.1 新增 `server/test/rule/vfs.lua` 并挂到测试入口的套件列表；探针来源目录写 `server/tmp/`（已 gitignore）并在用例结束清理；验证：`--test rule.vfs` 全绿
- [x] 5.2 用例覆盖规格里每个 Scenario（两种来源写法、容器展开、非法写法、默认来源、覆盖、并集与目录合并、不缓存、来源不存在、跨来源只执行生效版本、相对路径依赖）；验证：逐条对上，缺失的补齐
- [x] 5.3 既有 `server/test/rule/init.lua` 适配新的默认来源与逻辑路径（探针目录改为「来源目录 / 包目录」结构）；验证：`--test rule` 全绿

## 6. 文档

- [x] 6.1 `moe-kill-dev/references/architecture.md` 第 9 节：新增「包来源与虚拟文件系统」小节（两种写法、覆盖规则、不缓存、相对路径依赖），补「两套排序方向对照表」
- [x] 6.2 `moe-kill-dev/references/{infrastructure,architecture}.md` 与 `SKILL.md`：目录表 `game/` → `package/`，补 `server/rule/vfs.lua`
- [x] 6.3 `sanguosha-rules` 的规则集侧写法：`game/` → `package/`，补来源与相对路径依赖的写法

## 7. 验收

- [x] 7.1 `luamake -notest` 通过；全量 `--test` 全绿退出码 0；`--test rule.vfs` 与 `--test rule` 全绿；问题面板 information 及以上为 0
- [x] 7.2 两个来源存在同路径文件时，改后一个来源的文件立即生效（不重启进程、不清缓存）—— 已由 `--test rule.vfs` 的「不缓存」与 `--test rule` 的「跨来源时只执行生效版本」两个用例覆盖
- [x] 7.3 确认本批未引入包 / 名字路由语义（`标准.杀`、裸名路由、同包重名报错都不在本变更）
