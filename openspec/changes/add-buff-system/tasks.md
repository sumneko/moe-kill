# Tasks

## 1. 内核：Buff

- [ ] 1.1 新增 `server/core/buff.lua`：`Buff` 类（`name` / `host`；`attach(disposer)` / `on(时机, 回调)` / `remove()`，移除幂等）+ `server/core/init.lua` 装载
- [ ] 1.2 `server/core/player.lua`：`buffs` 表（宿主持有）+ `addBuff(名字)` / `getBuffs()` / `hasBuff(名字)`；类型注解
- [ ] 1.3 用例（新 `server/test/core/buff.lua`）：挂上查得到 / 同名并存 / `remove` 幂等 / `attach` 的资源随移除撤销 / `on` 的订阅随移除不再触发 / `getBuffs` 返回快照
- [ ] 1.4 全量 `server/bin/moe-kill.exe --test` 全绿 + 问题面板 information 及以上为 0

## 2. 文档

- [ ] 2.1 `architecture.md`：对象清单加 `Buff` 一行（「生命周期归内容、资源与订阅记在 buff 上、与创建者解耦」）
- [ ] 2.2 `progress.md` 记录；首个消费者指向 `add-qinggang-sword`
