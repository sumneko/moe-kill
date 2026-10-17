import { html } from 'htm/preact';
import type { Proto } from '../proto';
import type { Agent } from '../state/agent';

/** 设置卡片：一条一行，改了立刻提交 —— 只有本人看得见（别人的设置不下发） */
export function SettingsCard(props: { agent: Agent; onClose: () => void }) {
    const list = [...props.agent.settings.values()];
    return html`<div id="settings">
        <div class="head">
            <span class="title">设置</span>
            <button onClick=${props.onClose}>关闭</button>
        </div>
        ${list.length === 0 ? html`<p class="hint">这一局没有可改的设置</p>` : null}
        ${list.map((one) => html`<label class="row" key=${one.name} title=${one.describe ?? ''}>
            ${field(props.agent, one)}
            <span class="name">${one.name}</span>
        </label>`)}
        ${list.some((one) => one.describe) ? html`<p class="hint">${list.find((one) => one.describe)?.describe}</p>` : null}
    </div>`;
}

/** 一个设置的控件：布尔画勾、数字画数字框、文本画输入框 */
function field(agent: Agent, one: Proto.Setting) {
    if (typeof one.value === 'boolean') {
        return html`<input
            type="checkbox"
            checked=${one.value}
            onChange=${(event: Event) => void agent.changeSetting(one.name, (event.target as HTMLInputElement).checked)}
        />`;
    }
    if (typeof one.value === 'number') {
        return html`<input
            type="number"
            value=${String(one.value)}
            onChange=${(event: Event) => void agent.changeSetting(one.name, Number((event.target as HTMLInputElement).value))}
        />`;
    }
    return html`<input
        type="text"
        value=${String(one.value)}
        onChange=${(event: Event) => void agent.changeSetting(one.name, (event.target as HTMLInputElement).value)}
    />`;
}
