import { render } from 'preact';
import { html } from 'htm/preact';
import './style.css';
import { Agent } from './agent';
import { attachRobot } from './robot';
import { Shell } from './ui';

/** 一局在浏览器这边的镜像 */
const agent = new Agent();

const app = document.getElementById('app');
if (!app) {
    throw new Error('界面上没有 #app');
}

/** 局面变了就整块重画（preact 只改真的动过的那几处） */
function draw(): void {
    render(html`<${Shell} agent=${agent} />`, app as HTMLElement);
}

agent.onChange = draw;
draw();

/** 带 `?robot=名字` 打开就是一台机器玩家：自己连上、坐进来、把每条询问都答掉 */
const robot = new URLSearchParams(location.search).get('robot');
if (robot) {
    attachRobot(agent, robot);
}
