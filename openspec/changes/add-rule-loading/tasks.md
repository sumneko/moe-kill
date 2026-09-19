# Tasks

## 1. 中文标识符（已完成，记账）

- [x] 1.1 新增 `make/lua-patch/chinese-identifier/lua55.patch`：`lctype.h` 里 `lisutf8byte(c) = (c) >= 0x80`，`lislalpha` / `lislalnum` 接受非 ASCII 字节（EOZ 的 `-1` 不满足，不会误判）；验证：补丁能干净应用到 `3rd/bee.lua/3rd/lua55`
- [x] 1.2 新增 `make/lua-patch/apply.lua`：整树复制 + 依序 `git apply`，打补丁前把 CRLF 规范化为 LF；验证：脚本单独跑能成功，且重复跑结果一致
- [x] 1.3 `make.lua` 改为自接补丁链（optchain + 中文标识符 → `build/moe-patched/lua55`），并用自有 `source_moe_lua` 编译（镜像 bee 的 `source_lua`：含 `3rd/lua-patch` include、平台 defines、MSVC `BEE_FAST_SETJMP` + `/std:c11`）；验证：`luamake -notest` 通过、`3rd/bee.lua` 工作区无改动
- [x] 1.4 `.luarc.json` 打开 `runtime.unicodeName`；验证：含中文标识符的文件能被解析出符号且不报名称相关诊断
- [x] 1.5 运行时冒烟：临时脚本使用中文变量 / 函数名 / 表键并执行；验证：输出正确、退出码 0（验证后删除临时脚本）
- [x] 1.6 回归：全量 `--test` 全绿、退出码 0（换用打过补丁的 Lua 后无回归）

## 2. 加载器骨架（`server/rule/`）

- [ ] 2.1 建立 `server/rule/init.lua`（门面 `moe.rule`）与规则表：按名字查询 / 登记条目，清空；验证：`--test rule` 能跑出用例，且同名查询返回同一条
- [ ] 2.2 在 `server/moe-kill.lua` 挂 `moe.rule`（不进可重载集合）；验证：`moe.rule` 可用，且 `moe.reload` 的重载名单里没有 `rule.*`
- [ ] 2.3 加载一个文件：读源码 → `load(chunk, '@' + 路径)` → 执行；失败以错误抛出；验证：加载成功与语法错误的用例都通过

## 3. 清单、目录与去重

- [ ] 3.1 `load(清单)`：按清单顺序加载；清单项为目录时展开其中所有文件（子目录递归）；验证：顺序与展开的用例通过
- [ ] 3.2 同一轮加载内同一文件只执行一次（去重集合）；验证：重复引用的用例通过
- [ ] 3.3 引用不存在的文件/目录时以错误结束并指出该项；验证：该用例通过
- [ ] 3.4 验证加载不走模块系统：加载后的文件不出现在 `package.loaded`，也不在 `moe.reload` 的登记集合里；验证：该用例通过

## 4. 依赖声明

- [ ] 4.1 `rule.depends { ... }`：执行到该行时同步把依赖加载完（依赖项按文件解释，不存在再按目录展开）；验证：依赖先于本文件其余代码执行的用例通过
- [ ] 4.2 依赖递归（依赖的依赖也先满足）与防环；验证：两层依赖与互相依赖的用例都通过

## 5. 定义入口与重载

- [ ] 5.1 `rule.card '名字'` 取得或创建定义并登记进规则表，链式方法登记回调且返回同一条定义；验证：链式与同名用例通过
- [ ] 5.2 `load()` 重载语义：清空规则表 + 重新按清单加载（省略清单时用上次的）；验证：重载后旧条目查不到、文件被重新执行的用例通过
- [ ] 5.3 规则集文件的执行环境里只注入 `rule`（不需要 `require`）；验证：一个不使用 `require` 的规则集文件能被正常加载

## 6. 测试与文档

- [ ] 6.1 新增 `server/test/rule/init.lua` 并挂到测试入口的套件列表；验证：`--test rule` 全绿
- [ ] 6.2 用例覆盖规格里的每个 Scenario（清单/目录/去重/依赖/防环/定义/重载/失败）；验证：逐条对上，缺失的补齐
- [ ] 6.3 测试用的规则集文件放 `server/tmp/`（已 gitignore）并在用例结束时清理；验证：跑完不留残留
- [ ] 6.4 `moe-kill-dev` 的 `architecture.md`：新增「规则集加载」一节（与热重载的区别、清单/依赖/定义入口、清空重载）
- [ ] 6.5 `moe-kill-dev` 的 `infrastructure.md`：新增「Lua 源码补丁链」一节（为什么自接、要对照 bee 的 `source_lua`、CRLF 坑、如何加新补丁）
- [ ] 6.6 `sanguosha-rules` 技能：补「规则集侧写法」（`rule.card` / `rule.depends`、依赖写在文件顶部、可用中文标识符）

## 7. 验收

- [ ] 7.1 `luamake -notest` 编译通过（含补丁链）；全量 `--test` 全绿退出码 0；`--test rule` 全绿；问题面板 information 及以上为 0
- [ ] 7.2 手工核对一次「加一个新文件进清单即可生效、从清单移除即失效」，确认清单就是唯一入口
- [ ] 7.3 确认本批未引入卸载能力（没有按名单卸载的接口），且规则集加载与热重载在实现上互不牵连
