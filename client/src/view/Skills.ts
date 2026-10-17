import { html } from 'htm/preact';
import type { Agent } from '../state/agent';

/** 我的技能（桌子右下角常驻）：只切自动 / 看描述 —— 发动走询问条那排按钮 */
export function MySkills(props: { agent: Agent }) {
    const me = props.agent.me;
    if (me === null) {
        return null;
    }
    const mine = [...props.agent.skills.values()]
        .filter((skill) => skill.player === me)
        .sort((left, right) => left.id - right.id);
    if (mine.length === 0) {
        return null;
    }
    return html`<div id="skills">${mine.map((skill) => {
        const text = props.agent.text(skill.name);
        if (skill.auto === undefined) {
            return html`<span key=${skill.id} class=${`chip${skill.disabled ? ' off' : ''}`} title=${text}>${skill.name}</span>`;
        }
        const tip = [text, skill.disabled
            ? '已被禁用'
            : (skill.auto ? '自动（点一下改手动）' : '手动（点一下改自动）')]
            .filter((one) => one !== undefined && one !== '')
            .join('\n');
        return html`<button
            key=${skill.id}
            class=${[skill.auto ? 'auto' : '', skill.disabled ? 'off' : ''].filter((one) => one.length > 0).join(' ')}
            title=${tip}
            disabled=${skill.disabled === true}
            onClick=${() => void props.agent.changeSkillAuto(skill.id, !skill.auto)}
        >${skill.name}</button>`;
    })}</div>`;
}
