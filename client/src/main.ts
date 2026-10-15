import { render } from 'preact';
import { html } from 'htm/preact';
import './style.css';
import { Agent } from './agent';
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
