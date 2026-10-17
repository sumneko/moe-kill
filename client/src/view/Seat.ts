import { html } from 'htm/preact';
import type { Proto } from '../proto';
import type { Agent } from '../state/agent';
import { EquipList } from './Equip';
import { Head, HeroCard, type Pop } from './HeroCard';
import { attr, seatCards } from './format';

/** 别人的座位：头顶名字 + 武将卡 + 装备条 */
export function Seat(props: {
    agent: Agent;
    player: Proto.Player;
    left: number;
    top: number;
    active?: boolean;
    pickable?: boolean;
    target?: boolean;
    pops?: Pop[];
    onClick?: () => void;
}) {
    const id = props.player.base.id;
    const zoned = seatCards(props.agent, id);
    const dead = !props.player.base.alive;
    const dying = !dead && (attr(props.player, '体力') ?? 1) <= 0;
    const cls = [
        'seat',
        props.active ? 'active' : '',
        props.pickable ? 'pickable' : '',
        props.target ? 'target' : '',
        dead ? 'dead' : '',
    ].filter((one) => one.length > 0).join(' ');
    return html`<div
        class=${cls}
        data-fly=${`seat:${id}`}
        style=${`left:${props.left}px;top:${props.top}px`}
        onClick=${props.onClick}
    >
        <${Head} player=${props.player} />
        <${HeroCard}
            agent=${props.agent}
            player=${props.player}
            hand=${zoned.hand.length}
            judges=${zoned.judging}
            dead=${dead}
            dying=${dying}
            pops=${props.pops}
        />
        <div class="equips"><${EquipList} agent=${props.agent} owner=${id} equip=${zoned.equip} /></div>
    </div>`;
}
