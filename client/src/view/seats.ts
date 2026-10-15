/** 座位落点：按「从我起沿行动顺序数」的下标排（0 号是我，不在这里） */
const SLOTS: Record<number, { left: number; top: number }[]> = {
    // 4 人：右（下家）/ 上（对家）/ 左（上家）
    4: [
        { left: 1160, top: 130 },
        { left: 590, top: 48 },
        { left: 14, top: 130 },
    ],
    // 8 人：沿顺时针从我的右下往上绕一圈
    8: [
        { left: 1160, top: 380 },
        { left: 1080, top: 110 },
        { left: 840, top: 48 },
        { left: 590, top: 48 },
        { left: 340, top: 48 },
        { left: 94, top: 110 },
        { left: 14, top: 380 },
    ],
};

/** 除我以外的人各摆哪儿（认不出的人数就绕一圈） */
export function seatSlots(seats: number): { left: number; top: number }[] {
    const known = SLOTS[seats];
    if (known) {
        return known;
    }
    const count = Math.max(seats - 1, 0);
    return Array.from({ length: count }, (_, index) => {
        const angle = Math.PI / 2 + (index + 1) * Math.PI * 2 / Math.max(seats, 1);
        return {
            left: Math.round(640 + Math.cos(angle) * 470 - 50),
            top: Math.round(300 + Math.sin(angle) * 200 - 75),
        };
    });
}
