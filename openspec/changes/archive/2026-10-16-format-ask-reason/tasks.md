## 1 前端

- [x] 1.1 `format.ts` 加 `formatText(text, tables)`：解析 `${函数名:内容}` / 第一个 `@{名字:值}` / `{名字}` / `{名字#代码}`，返回片段数组
- [x] 1.2 `format.ts` 加默认的翻译表与颜色表（`locale` / `suit`… 与几个颜色代码）
- [x] 1.3 `locale` 递归展开 + `visited`（同一 id 只展开一次）
- [x] 1.4 `Ask.ts` 的 `askTitle` 改成返回片段数组，`reason` 走 `formatText`
- [x] 1.5 抬头的样式走内联 `color`（片段自带色值，不另开 CSS 类）

## 2 内容侧

- [x] 2.1 `杀` / `万箭齐发` / `南蛮入侵` / `决斗` / `无懈可击` 的 `reason` 改成 `${locale:…}` + `@{…}` 语法

## 3 文档与规格

- [x] 3.1 活规格 `openspec/specs/jsonrpc-protocol` 合入本变更的增量（归档时）
- [x] 3.2 `architecture.md` 的 `askPlayCard` / `askCard` 行补一句 `reason` 的格式约定
- [x] 3.3 `progress.md` §1 记一条

## 4 收尾

- [x] 4.1 后端测试全绿（`server/bin/moe-kill.exe --test`，报出基线）
- [x] 4.2 前端 `npm --prefix client run build` 通过
- [x] 4.3 检查问题面板（information 及以上清零）
- [x] 4.4 浏览器真链路看一眼抬头渲染
