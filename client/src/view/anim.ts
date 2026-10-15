/** 舞台宽度（画布坐标的基准） */
const STAGE_W = 1280;

/** 上一帧各锚点元素的位置（飞行起点） */
const prev = new Map<string, DOMRect>();

/** 画布 → 屏幕的缩放 */
function scaleOf(root: HTMLElement): number {
    const stage = root.querySelector<HTMLElement>('#stage');
    const width = stage?.getBoundingClientRect().width ?? 0;
    return width > 0 ? width / STAGE_W : 1;
}

/** 记下这一帧所有锚点的位置（渲染后叫） */
export function measure(root: HTMLElement): void {
    prev.clear();
    for (const el of root.querySelectorAll<HTMLElement>('[data-fly]')) {
        const key = el.dataset.fly;
        if (key) {
            prev.set(key, el.getBoundingClientRect());
        }
    }
}

/** 让一个锚点从上一帧的位置飞过来（没记过位置就不动） */
export function flyTo(root: HTMLElement, key: string, duration = 280): void {
    const el = root.querySelector<HTMLElement>(`[data-fly="${key}"]`);
    const before = prev.get(key);
    if (!el || !before) {
        return;
    }
    const after = el.getBoundingClientRect();
    const scale = scaleOf(root);
    const dx = (before.left - after.left) / scale;
    const dy = (before.top - after.top) / scale;
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1) {
        return;
    }
    el.animate([
        { transform: `translate(${dx}px, ${dy}px)` },
        { transform: 'translate(0px, 0px)' },
    ], { duration, easing: 'cubic-bezier(.35,.7,.35,1)' });
}
