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


def bgm():
    """A 小调 128BPM 背景音乐：贝斯 + 和弦垫 + 琶音 + 鼓点，8 小节无缝循环"""
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 8
    total = seconds(beat * 4 * bars)
    out = [0.0] * total
    chords = [(220.0, 261.63, 329.63), (174.61, 220.0, 261.63), (130.81, 164.81, 196.0), (196.0, 246.94, 293.66)]  # Am F C G
    roots = [110.0, 87.31, 65.41, 98.0]

    def add_note(start_s, dur, f, vol, wave_fn=math.sin, r=0.8):
        n = seconds(dur)
        s0 = seconds(start_s)
        for i in range(min(n, total - s0)):
            ph = 2 * math.pi * f * i / SR
            out[s0 + i] += wave_fn(ph) * vol * env(i, n, 0.02, r)

    for bar in range(bars):
        ch = bar % 4
        bar_start = bar * beat * 4
        for b in range(4):  # 贝斯：每拍根音
            add_note(bar_start + b * beat, beat * 0.9, roots[ch], 0.30, square, 0.5)
        for f in chords[ch]:  # 和弦垫
            add_note(bar_start, beat * 4, f, 0.06, math.sin, 1.2)
        seq = chords[ch] + (chords[ch][1],)
        for s16 in range(16):  # 十六分琶音
            add_note(bar_start + s16 * beat / 4, beat / 4 * 0.85, seq[s16 % 4] * 2, 0.05, math.sin, 0.6)
        n_h = seconds(beat * 0.15)  # 八分 hi-hat
        for h8 in range(8):
            s0 = seconds(bar_start + h8 * beat * 0.5)
            for i in range(n_h):
                if s0 + i < total:
                    out[s0 + i] += random.uniform(-1, 1) * 0.05 * env(i, n_h, 0.001, 3.0)
    save("bgm", out, 0.55)


if __name__ == "__main__":
    main()
    bgm()
