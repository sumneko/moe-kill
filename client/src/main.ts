import { render } from 'preact';
import { html } from 'htm/preact';
import { Agent } from './state/agent';
import { attachRobot } from './robot';

/** 后端默认听这个口 */
const DEFAULT_PORT = 31415;

const params = new URLSearchParams(location.search);

/** 一局在浏览器这边的镜像 */
const agent = new Agent();

/** 后端地址（`?server=` 可以改） */
const url = params.get('server') ?? `ws://${location.hostname || 'localhost'}:${DEFAULT_PORT}`;

/** 起界面：默认牌桌；`?ui=classic` 走老界面（能答所有询问，含面板拖拽） */
async function boot(): Promise<void> {
    const app = document.getElementById('app');
    if (!app) {
        throw new Error('界面上没有 #app');
    }
    if (params.get('ui') === 'classic') {
        await import('./style.css');
        const { Shell } = await import('./ui');
        const draw = () => render(html`<${Shell} agent=${agent} />`, app);
        agent.onChange = draw;
        draw();
        return;
    }
    await import('./view/table.css');
    const { App } = await import('./view/App');
    const draw = () => render(html`<${App} agent=${agent} events=${agent.drainEvents()} />`, app);
    agent.onChange = draw;
    draw();
}

const robot = params.get('robot');
void boot()
    .then(() => {
        if (robot) {
            attachRobot(agent, robot);
            return undefined;
        }
        return agent.connect(url).then(() => agent.join(params.get('name') ?? '玩家'));
    })
    .catch((err: unknown) => agent.log(`起不来：${err instanceof Error ? err.message : String(err)}`));
