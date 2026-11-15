"""Procedural chiptune SFX + BGM generator for Godot Parkour.

Stdlib only (wave/struct/math). Writes 22050 Hz mono 16-bit WAVs into
res://audio/. Run: python tools/gen_audio.py
"""
import math
import os
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.6 / peak if peak > 0.6 else 1.0
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * scale)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("wrote", path, len(samples), "samples", round(len(samples) / SR, 2), "s")


def env(i, n, attack=0.005):
    t = i / SR
    dur = n / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = max(0.0, 1.0 - t / dur)
    return a * d


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def saw(phase):
    return 2.0 * (phase % 1.0) - 1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def midi(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def sfx_jump():
    n = int(0.13 * SR)
    out = []
    ph = 0.0
    for i in range(n):
        f = 330.0 + 330.0 * (i / n)
        ph += f / SR
        out.append(square(ph) * env(i, n) * 0.5)
    return out


def sfx_land():
    n = int(0.1 * SR)
    out = []
    import random
    rng = random.Random(7)
    ph = 0.0
    for i in range(n):
        ph += 95.0 / SR
        noise = rng.uniform(-1, 1)
        e = env(i, n, attack=0.001)
        out.append((math.sin(2 * math.pi * ph) * 0.6 + noise * 0.4) * e * 0.5)
    return out


def sfx_coin():
    out = []
    for freq, dur in [(987.77, 0.06), (1318.5, 0.13)]:
        n = int(dur * SR)
        ph = 0.0
        for i in range(n):
            ph += freq / SR
            out.append(square(ph, 0.25) * env(i, n) * 0.4)
    return out


def sfx_fall():
    n = int(0.45 * SR)
    out = []
    ph = 0.0
    for i in range(n):
        f = 500.0 - 400.0 * (i / n)
        ph += f / SR
        out.append(saw(ph) * env(i, n) * 0.4)
    return out


def sfx_finish():
    out = []
    notes = [72, 76, 79, 84, 88]
    for k, m in enumerate(notes):
        dur = 0.1 if k < 4 else 0.35
        n = int(dur * SR)
        f = midi(m)
        ph = 0.0
        for i in range(n):
            ph += f / SR
            out.append(square(ph, 0.3) * env(i, n, attack=0.004) * 0.4)
    return out


def sfx_bounce():
    n = int(0.22 * SR)
    out = []
    ph = 0.0
    for i in range(n):
        f = 180.0 + 700.0 * (i / n) ** 1.5
        ph += f / SR
        out.append(triangle(ph) * env(i, n, attack=0.003) * 0.55)
    return out


def sfx_checkpoint():
    out = []
    for freq, dur in [(659.25, 0.07), (880.0, 0.16)]:
        n = int(dur * SR)
        ph = 0.0
        for i in range(n):
            ph += freq / SR
            out.append(triangle(ph) * env(i, n, attack=0.004) * 0.45)
    return out


def bgm():
    bpm = 160.0
    beat = 60.0 / bpm
    eighth = beat / 2.0
    bars = [
        (48, [76, 79, 84, 79, 76, 79, 84, 79]),   # C
        (45, [69, 72, 76, 72, 69, 72, 76, 72]),   # Am
        (41, [65, 69, 72, 69, 65, 69, 72, 69]),   # F
        (43, [67, 71, 74, 71, 67, 71, 74, 71]),   # G
    ]
    total = int(len(bars) * 4 * beat * SR)
    lead = [0.0] * total
    bass = [0.0] * total
    hat = [0.0] * total
    import random
    rng = random.Random(3)
    for bi, (root, mel) in enumerate(bars):
        bar_start = bi * 4 * beat
        # lead: eighth notes
        for ei, m in enumerate(mel):
            start = int((bar_start + ei * eighth) * SR)
            n = int(eighth * SR)
            f = midi(m)
            ph = 0.0
            for i in range(n):
                ph += f / SR
                idx = start + i
                if idx < total:
                    lead[idx] += square(ph, 0.5) * env(i, n, attack=0.004) * 0.32
        # bass: quarter notes triangle
        for b in range(4):
            start = int((bar_start + b * beat) * SR)
            n = int(beat * SR)
            f = midi(root)
            ph = 0.0
            for i in range(n):
                ph += f / SR
                idx = start + i
                if idx < total:
                    bass[idx] += triangle(ph) * env(i, n, attack=0.006) * 0.3
        # hat: off-beat noise
        for ei in range(8):
            if ei % 2 == 1:
                start = int((bar_start + ei * eighth) * SR)
                n = int(0.03 * SR)
                for i in range(n):
                    idx = start + i
                    if idx < total:
                        hat[idx] += rng.uniform(-1, 1) * env(i, n, attack=0.001) * 0.1
    return [lead[i] + bass[i] + hat[i] for i in range(total)]


if __name__ == "__main__":
    write_wav("jump.wav", sfx_jump())
    write_wav("land.wav", sfx_land())
    write_wav("coin.wav", sfx_coin())
    write_wav("fall.wav", sfx_fall())
    write_wav("finish.wav", sfx_finish())
    write_wav("bounce.wav", sfx_bounce())
    write_wav("checkpoint.wav", sfx_checkpoint())
    write_wav("bgm.wav", bgm())
    print("ALL AUDIO DONE")
