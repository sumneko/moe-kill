import { html } from 'htm/preact';
import type { Agent } from '../state/agent';

/** 调试抽屉：手写发送 + 事件流 */
export function Drawer(props: {
    agent: Agent;
    /** 手写的那一包（原样发上去） */
    raw: string;
    onRawChange: (value: string) => void;
    onSend: () => void;
}) {
    return html`<div id="drawer">
        <div class="send">
            <input
                size="24"
                placeholder=${'{"usedViewAs":1,...}'}
                value=${props.raw}
                onInput=${(event: Event) => props.onRawChange((event.target as HTMLInputElement).value)}
            />
            <button onClick=${props.onSend}>手写发送</button>
        </div>
        <h3>事件流（最近 ${props.agent.logs.length} 条）</h3>
        ${[...props.agent.logs].reverse().map((line, index) => html`<div class="line" key=${index}>${line}</div>`)}
    </div>`;
}
