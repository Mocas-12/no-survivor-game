# -*- coding: utf-8 -*-
"""游戏音效合成器：纯数学合成 8-bit 风格 WAV，运行一次生成 assets/sounds/*.wav"""
import math
import os
import random
import struct
import wave

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds"))
os.makedirs(OUT, exist_ok=True)
SR = 22050


def save(name, samples, peak=0.75):
    m = max(1e-9, max(abs(s) for s in samples))
    scale = peak / m
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, f"{name}.wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("saved", name)


def seconds(n):
    return int(SR * n)


def env(i, n, a=0.01, r=0.6):
    """attack/release 包络"""
    t = i / n
    attack = min(1.0, t / max(a, 1e-6))
    release = (1 - t) ** r
    return attack * release


def sweep(f0, f1, dur, wave_fn=math.sin, a=0.01, r=2.5):
    n = seconds(dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        out.append(wave_fn(phase) * env(i, n, a, r))
    return out


def square(ph):
    return 1.0 if (ph / (2 * math.pi)) % 1.0 < 0.5 else -1.0


def noise(dur, r=1.8, lp=0.25):
    """低通白噪声（爆炸底）"""
    n = seconds(dur)
    out, prev = [], 0.0
    for i in range(n):
        prev += (random.uniform(-1, 1) - prev) * lp
        out.append(prev * env(i, n, 0.005, r))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def cat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def gain(track, g):
    return [s * g for s in track]


def main():
    random.seed(7)
    # 激光射击：快速下滑的方波
    save("shoot", sweep(950, 240, 0.09, square, 0.002, 2.2), 0.5)
    # 命中：短噪声 + 低频点
    save("hit", mix(noise(0.06, 3.5, 0.6), sweep(300, 120, 0.06, a=0.002)), 0.55)
    # 爆炸：低通噪声 + 低频boom
    save("explode", mix(noise(0.42, 2.2, 0.12), gain(sweep(120, 40, 0.42, a=0.002, r=1.6), 0.9)), 0.85)
    # 拾取水晶：上行双音
    save("pickup", cat(sweep(660, 660, 0.07, a=0.01, r=0.4), sweep(990, 990, 0.1, a=0.01, r=1.2)), 0.5)
    # 升级：上行琶音
    arp = []
    for f in (523, 659, 784, 1046):
        arp.extend(sweep(f, f, 0.11, a=0.01, r=0.8))
    save("levelup", mix(arp, gain(sweep(130, 130, 0.44, r=1.2), 0.5)), 0.7)
    # 变身：能量上升滑音 + 闪亮高频
    save("transform", mix(sweep(280, 1400, 0.55, a=0.02, r=1.4), gain(sweep(2400, 3200, 0.55, a=0.3, r=2.0), 0.25)), 0.75)
    # BOSS 警报：双音警笛
    siren = []
    for _ in range(3):
        siren.extend(sweep(440, 440, 0.14, square, 0.005, 0.3))
        siren.extend(sweep(554, 554, 0.14, square, 0.005, 0.3))
    save("warning", siren, 0.5)
    # BOSS 死亡：多重爆炸
    save("boss_die", mix(noise(1.1, 1.6, 0.08), gain(sweep(90, 30, 1.1, a=0.002, r=1.2), 1.0), gain(noise(0.5, 3.0, 0.4), 0.6)), 0.9)
    # 游戏结束：下行音
    save("gameover", mix(sweep(420, 95, 0.9, a=0.01, r=1.2), gain(sweep(210, 48, 0.9, a=0.01, r=1.2), 0.6)), 0.7)


def saw(ph):
    return 2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0


def bgm():
    """A 小调 140BPM 战斗 BGM：鼓组驱动 + 锯齿贝斯 + 力量和弦 + 主旋律，16 小节无缝循环"""
    bpm = 140.0
    beat = 60.0 / bpm
    bars = 16
    total = seconds(beat * 4 * bars)
    out = [0.0] * total
    roots = [110.0, 87.31, 65.41, 98.0, 110.0, 87.31, 65.41, 82.41]   # A F C G A F C E
    fifths = [164.81, 130.81, 98.0, 146.83, 164.81, 130.81, 98.0, 123.47]

    def add_note(start_s, dur, f, vol, wave_fn=math.sin, r=0.8, lp=0.0, detune=0.0):
        n = seconds(dur)
        s0 = seconds(start_s)
        prev = 0.0
        for i in range(min(n, total - s0)):
            ph = 2 * math.pi * f * i / SR
            v = wave_fn(ph)
            if detune > 0.0:
                v = (v + wave_fn(2 * math.pi * f * (1 + detune) * i / SR)) * 0.5
            if lp > 0.0:
                prev += (v - prev) * lp
                v = prev
            out[s0 + i] += v * vol * env(i, n, 0.015, r)

    for bar in range(bars):
        ch = bar % 8
        bar_start = bar * beat * 4
        # 底鼓：每拍
        for b in range(4):
            n_k = seconds(0.11)
            s0 = seconds(bar_start + b * beat)
            for i in range(n_k):
                t = i / n_k
                out[s0 + i] += math.sin(2 * math.pi * (150 - 105 * t) * i / SR) * 0.55 * (1 - t) ** 1.5
        # 军鼓：2、4 拍
        for b in (1, 3):
            s0 = seconds(bar_start + b * beat)
            n_s = seconds(0.09)
            for i in range(n_s):
                out[s0 + i] += random.uniform(-1, 1) * 0.28 * env(i, n_s, 0.001, 2.0)
        # 踩镲：十六分
        for s16 in range(16):
            s0 = seconds(bar_start + s16 * beat / 4)
            n_h = seconds(0.03)
            for i in range(min(n_h, total - s0)):
                out[s0 + i] += random.uniform(-1, 1) * 0.045 * env(i, n_h, 0.001, 3.0)
        # 锯齿贝斯：八分驱动（根音 + 指向五度的律动）
        for e in range(8):
            f = roots[ch] if e % 4 != 3 else fifths[ch] / 2
            add_note(bar_start + e * beat / 2, beat * 0.48, f, 0.26, saw, 0.6, 0.28, 0.006)
        # 力量和弦垫（根音 + 五度 + 八度）
        for f in (roots[ch], fifths[ch], roots[ch] * 2):
            add_note(bar_start, beat * 4, f, 0.05, saw, 1.2, 0.12, 0.004)
        # 十六分琶音（高八度）
        seq = [roots[ch] * 2, fifths[ch] * 2, roots[ch] * 4, fifths[ch] * 2]
        for s16 in range(16):
            add_note(bar_start + s16 * beat / 4, beat / 4 * 0.8, seq[s16 % 4], 0.045, math.sin, 0.5)

    # 主旋律（后 8 小节进入，A 小调五声）：英雄感动机
    pent = [440.0, 523.25, 587.33, 659.25, 783.99]
    motif = [
        (0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 4), (3, 2), (3.5, 1),
        (4, 2), (5, 1), (5.5, 0), (6, 1), (7, -1),
        (8, 0), (8.5, 1), (9, 2), (9.5, 4), (10, 3), (11, 2), (11.5, 1),
        (12, 2), (13, 1), (13.5, 0), (14, -2), (15, -1),
    ]
    for rep in range(4):
        base_bar = 8 + rep * 2
        for (off_e, idx) in motif:
            idx2 = max(0, min(4, idx))
            f = pent[idx2] * (2 if rep % 2 == 1 and idx2 >= 3 else 1)
            add_note(base_bar * beat + off_e * beat, beat * 0.55, f, 0.09, math.sin, 0.5)

    save("bgm", out, 0.6)


if __name__ == "__main__":
    main()
    bgm()
