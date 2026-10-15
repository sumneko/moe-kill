import { html } from 'htm/preact';
import type { Proto } from '../proto';
import type { Agent } from '../state/agent';
import { attr, cardLabel, cardFaceOf, heroName, identityOf, KINGDOM_CLASS, kingdomOf } from './format';

/** 一条要播的跳字 */
export interface Pop {
    key: number;
    delta: number;
}

/** 血量格：亮的从下往上数 */
function pips(hp: number, max: number) {
    const on = Math.max(Math.min(hp, max), 0);
    return html`${Array.from({ length: on }, (_, index) => html`<div class="pip on" key=${`on${index}`}></div>`)}${
        Array.from({ length: Math.max(max - on, 0) }, (_, index) => html`<div class="pip" key=${`off${index}`}></div>`)}`;
}

/** 武将卡：立绘 + 四角（判定 / 身份 / 手牌数 / 血量）—— 自己与别人共用 */
export function HeroCard(props: {
    agent: Agent;
    player: Proto.Player;
    hand: number;
    judges: number[];
    dead?: boolean;
    pops?: Pop[];
}) {
    const { agent, player } = props;
    const identity = identityOf(player);
    const stamp = identity === '主公' ? 'loyal' : identity === '内奸' ? 'spy' : '';
    const kingdom = kingdomOf(player);
    const hp = attr(player, '体力') ?? 0;
    const max = attr(player, '体力上限') ?? hp;
    return html`<div class=${`portrait ${KINGDOM_CLASS[kingdom ?? ''] ?? ''}`}>
        <div class="art"></div>
        <div class="judge-col">
            ${props.judges.map((id) => html`<div class="judge" key=${id} title=${cardLabel(agent, id)}>
                <span>${(cardFaceOf(agent, id)?.name ?? '?').slice(0, 1)}</span>
            </div>`)}
        </div>
        <div class="pips">${pips(hp, max)}</div>
        ${kingdom ? html`<div class="kingdom">${kingdom}</div>` : null}
        ${identity ? html`<div class=${`stamp ${stamp}`}>${identity}</div>` : null}
        ${props.dead ? html`<div class="fallen">阵亡</div>` : null}
        <div class="hand-count">${props.hand}</div>
        ${(props.pops ?? []).map((pop) => html`<div
            class=${`pop ${pop.delta < 0 ? 'hurt' : 'heal'}`}
            key=${pop.key}
        >${pop.delta > 0 ? `+${pop.delta}` : pop.delta}</div>`)}
    </div>`;
}

/** 头顶那一行：武将名 + 玩家名 */
export function Head(props: { player: Proto.Player }) {
    const hero = heroName(props.player);
    return html`<div class="head">
        <span class="hero">${hero ?? '未选将'}</span>
        <span class="pname">${props.player.base.userName}</span>
    </div>`;
}
