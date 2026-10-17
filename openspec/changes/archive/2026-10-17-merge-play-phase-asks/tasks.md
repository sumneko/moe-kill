# Tasks

## 1. 内核：合体询问

- [x] 1.1 把 `AskUseSkill` 里「技能那半」的口径（选项收集、素材 / 目标校验、答复归一）抽成共享片段，`AskUseSkill` 改为调用它 —— 验证：`server/bin/moe-kill.exe --test` 全绿且基线数不变
- [x] 1.2 新增 `server/core/effect/ask-use.lua`（`AskUse : AskCard`）：选项分牌子半与技能半；`checkAnswer` 按答复给了 `card` / `viewAs` / `skill` 哪一样分发；两个执行入口 `:useCard()` / `:useSkill()`；三组都空时直接失败、不发询问 —— 验证：第 5.1 条的新套件通过
- [x] 1.3 `Game` 上加 `askUse` / `startAskUse` 两个入口，并把 `AskUse` 并进 `env-meta.lua` 里 `AskCard|AskUseCard|...` 那串载荷联合与时机声明 —— 验证：问题面板 0 诊断、既有用例仍绿

## 2. 协议

- [x] 2.1 `server/proto.d.lua`：`Proto.Request.Ask.Use` 增加可选的 `skill`、`Proto.Result.Ask.Use` 增加 `usedSkill`；删掉 `Proto.Request.Ask.UseSkill` 与 `Proto.Result.Ask.UseSkill`（`Proto.SkillPlan` 留着）—— 验证：`--gen-proto` 出来的 `client/src/proto.d.ts` 里有 `skill` / `usedSkill`、且搜不到 `Ask.UseSkill`
- [x] 2.2 `server/user/client-user.lua`：`askUseSkill` 的发送点改用 `Ask.Use`（params 只带 `skill`），两个 `resultShape` 合成一个 —— 验证：第 5.2 条的用例改完后通过
- [x] 2.3 `server/test/proto.lua` 的方法清单与形状断言同步 —— 验证：该套件通过

## 3. 内容侧

- [x] 3.1 `package/@基础/阶段/出牌阶段.lua` 改成一次 `game:askUse`，按答复给了牌还是技能分别调 `:useCard()` / `:useSkill()`，去掉 `effectRace` 那条 —— 验证：真链路日志里每轮出牌阶段只出现一条 `Ask.Use`

## 4. 前端

- [x] 4.1 `state/agent.ts` 的 `ASK_METHODS` 去掉 `Ask.UseSkill`；`view/Ask.ts` 把技能按钮那排并进 `Ask.Use` 分支（`skill` 组在就渲染）—— 验证：`npm --prefix client run build` 过，且出牌阶段一条询问里手牌与技能按钮同时可点
- [x] 4.2 `view/pick.ts` / `view/App.ts` 里按 `ask.method === 'Ask.UseSkill'` 分流的地方改成按答复内容分流（选牌答 `usedCard` / `usedViewAs`、选技能答 `usedSkill`）—— 验证：真链路上「用一张牌」与「发动一个技能」各成功一次

## 5. 用例

- [x] 5.1 新增 `server/test/core/effect/ask-use.lua`：只问牌 / 只问技能 / 同时问、答复三选一、越界答复被拒、三组都空时不发问 —— 验证：新套件全绿
- [x] 5.2 `server/test/rule/**` 与 `server/test/user/ask-use-skill.lua` 里按方法名 / `ask.kind` 认询问的探针改成认新的 `askUse` 与 `Ask.Use` —— 验证：全量用例 0 失败，且基线数逐个核对（不是只看「0 失败」）
- [x] 5.3 `server/test/rule/turn.lua` 里「出牌阶段两路并行」那段改成「一条询问」 —— 验证：该套件通过

## 6. 收尾

- [x] 6.1 跑 `server/bin/moe-kill.exe --test` 并在 `progress.md` 报出验收基线数；问题面板 information 及以上清到 0 —— 验证：0 失败 + 面板 0
- [x] 6.2 真链路（4 人局）验证三件事：出牌阶段不再出现第二条询问、答完牌不再闪「请发动一个技能」、技能可发动时按钮常亮 —— 验证：浏览器实测（可脚本化采样询问条）
- [x] 6.3 把这次的口径与踩到的坑写进 `.agents/skills/moe-kill-dev/references/progress.md`，并确认 `openspec/specs/jsonrpc-protocol/` 的增量随归档合入 —— 验证：文档与实现一致
