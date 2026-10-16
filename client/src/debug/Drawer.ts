import { html } from 'htm/preact';
import type { Agent } from '../state/agent';

/** 调试抽屉里能选的动画倍率（**时长乘数**：`0` = 没有动画，越大等得越久） */
const SPEEDS = [0, 0.5, 1, 2, 4];

/** 调试抽屉：手写发送 + 动画倍率 + 事件流 */
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
        ${props.agent.debug ? html`<div class="send">
            <span title="等待时长 = 节拍秒数 × 倍率：0 = 没有动画，2 就是等两倍久">动画倍率</span>
            ${SPEEDS.map((scale) => html`<button
                key=${scale}
                disabled=${props.agent.animScale === scale}
                onClick=${() => void props.agent.setAnimScale(scale)}
            >${scale}×</button>`)}
        </div>` : null}
        <h3>事件流（最近 ${props.agent.logs.length} 条）</h3>
        ${[...props.agent.logs].reverse().map((line, index) => html`<div class="line" key=${index}>${line}</div>`)}
    </div>`;
}
