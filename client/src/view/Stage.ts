import { html } from 'htm/preact';
import { useEffect, useRef } from 'preact/hooks';
import type { ComponentChildren } from 'preact';

/** 舞台宽度 */
const STAGE_W = 1280;
/** 舞台高度 */
const STAGE_H = 720;

/** 画布：1280×720 固定，按窗口等比缩放 */
export function Stage(props: { children: ComponentChildren }) {
    const stage = useRef<HTMLDivElement>(null);
    useEffect(() => {
        const fit = () => {
            const el = stage.current;
            if (el) {
                el.style.transform = `scale(${Math.min(window.innerWidth / STAGE_W, window.innerHeight / STAGE_H)})`;
            }
        };
        window.addEventListener('resize', fit);
        fit();
        return () => window.removeEventListener('resize', fit);
    }, []);
    return html`<div id="viewport"><div id="stage" ref=${stage}>${props.children}</div></div>`;
}
