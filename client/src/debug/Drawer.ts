import { html } from 'htm/preact';
import type { Agent } from '../state/agent';

/** 调试抽屉：事件流 */
export function Drawer(props: { agent: Agent }) {
    return html`<div id="drawer">
        <h3>事件流（最近 ${props.agent.logs.length} 条）</h3>
        ${[...props.agent.logs].reverse().map((line, index) => html`<div class="line" key=${index}>${line}</div>`)}
    </div>`;
}
