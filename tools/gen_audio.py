#!/usr/bin/env python3
"""Synthesise Robbie N+1's placeholder sounds into game/audio/*.wav.

Everything is generated from code (no samples, no licences to track) and is
deterministic: the same script always writes the same files.
Run from the repo root:  python3 tools/gen_audio.py
"""
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "game" / "audio"
rng = np.random.default_rng(20261016)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), btype="high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def env(n, attack=0.005, release=0.2, sustain_level=1.0):
    """Attack then exponential decay over n samples."""
    e = np.ones(n) * sustain_level
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0, 1, a)
    k = np.arange(n - a)
    e[a:] = np.exp(-k / max(1, release * SR))
    return e


def fade_loop(x, sec=0.4):
    """Crossfade the end into the start so the file loops without a click."""
    n = int(sec * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def echo(x, delay=0.18, feedback=0.45, taps=6):
    out = np.concatenate([x, np.zeros(int(delay * SR * taps))])
    for i in range(1, taps + 1):
        d = int(delay * SR * i)
        out[d:d + len(x)] += x * (feedback ** i)
    return out


def norm(x, peak=0.7):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write(name, x, peak=0.7):
    import wave
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(x) / SR:.2f}s")


def brown(n):
    w = rng.standard_normal(n)
    b = np.cumsum(w)
    b -= lowpass(b, 2.0, 1)   # remove drift
    return b / (np.max(np.abs(b)) or 1)


# --- ambience -----------------------------------------------------------------

def amb_dive():
    n = int(SR * 9)
    tt = t(9)
    rumble = lowpass(brown(n), 160, 2)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * tt / 4.5) ** 2
    hum = 0.15 * np.sin(2 * np.pi * 41 * tt) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 3))
    # far-off creaks
    creak = np.zeros(n)
    for start, f in [(1.7, 210), (5.9, 173)]:
        s = int(start * SR)
        m = int(0.9 * SR)
        g = np.sin(2 * np.pi * (f + 25 * np.sin(2 * np.pi * 3 * t(0.9))) * t(0.9)) * env(m, 0.2, 0.3)
        creak[s:s + m] += 0.08 * bandpass(g, 120, 400)
    return fade_loop(rumble * swell + hum + creak)


def amb_station():
    n = int(SR * 8)
    tt = t(8)
    mains = 0.5 * np.sin(2 * np.pi * 50 * tt) + 0.25 * np.sin(2 * np.pi * 100 * tt) + 0.1 * np.sin(2 * np.pi * 150 * tt)
    fan = bandpass(rng.standard_normal(n), 300, 2500) * 0.25
    beep = np.zeros(n)
    for start in [2.2, 6.1]:
        s = int(start * SR)
        m = int(0.08 * SR)
        beep[s:s + m] += 0.06 * np.sin(2 * np.pi * 1760 * t(0.08)) * env(m, 0.002, 0.03)
    return fade_loop(mains * 0.35 + fan + beep)


# --- dive events ----------------------------------------------------------------

def launch():
    n = int(SR * 0.6)
    tt = t(0.6)
    f = 1150 - 150 * tt / 0.6
    ping = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.003, 0.12)
    whoosh = lowpass(rng.standard_normal(n), 700) * env(n, 0.05, 0.25) * 0.5
    return echo(ping + whoosh, 0.21, 0.42, 6)


def jelly():
    n = int(SR * 1.2)
    tt = t(1.2)
    x = sum(a * np.sin(2 * np.pi * f * tt) * env(n, 0.004, d)
            for f, a, d in [(1568, 1.0, 0.35), (2349, 0.5, 0.25), (3136, 0.3, 0.15), (784, 0.4, 0.5)])
    return echo(x, 0.13, 0.3, 4)


def sting():
    n = int(SR * 0.35)
    tt = t(0.35)
    buzz = np.sign(np.sin(2 * np.pi * (180 + 600 * np.exp(-tt * 20)) * tt)) * env(n, 0.002, 0.08)
    crackle = highpass(rng.standard_normal(n), 2500) * env(n, 0.001, 0.05)
    return lowpass(buzz * 0.6 + crackle * 0.5, 5000)


def crash():
    n = int(SR * 0.7)
    tt = t(0.7)
    thump = np.sin(2 * np.pi * 70 * tt) * env(n, 0.002, 0.08)
    ring = sum(a * np.sin(2 * np.pi * f * tt) * env(n, 0.001, d)
               for f, a, d in [(620, 0.5, 0.25), (1033, 0.35, 0.18), (1710, 0.25, 0.1)])
    grit = lowpass(rng.standard_normal(n), 3000) * env(n, 0.001, 0.04)
    return thump + ring * 0.6 + grit * 0.6


def lurker_wake():
    n = int(SR * 0.7)
    tt = t(0.7)
    growl = lowpass(rng.standard_normal(n), 250) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * tt))
    tone = np.sin(2 * np.pi * (55 + 30 * tt) * tt)
    return (growl + tone * 0.6) * env(n, 0.15, 0.4)


def strike():
    n = int(SR * 0.6)
    tt = t(0.6)
    snap = highpass(rng.standard_normal(n), 900) * env(n, 0.001, 0.03)
    thud = np.sin(2 * np.pi * (90 * np.exp(-tt * 6) + 35) * tt) * env(n, 0.002, 0.18)
    return snap * 0.7 + thud


def valve():
    n = int(SR * 1.3)
    tt = t(1.3)
    f = 95 - 35 * tt / 1.3
    groan = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR)
    wet = bandpass(rng.standard_normal(n), 200, 900) * 0.3
    return (groan + wet) * env(n, 0.25, 0.5)


def laser():
    n = int(SR * 0.3)
    tt = t(0.3)
    f = 2200 * np.exp(-tt * 9) + 250
    z = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(n, 0.001, 0.1)
    return lowpass(z, 6000)


def exit_chime():
    notes = [523.25, 659.25, 783.99, 1046.5]
    out = np.zeros(int(SR * 1.6))
    for i, f in enumerate(notes):
        s = int(i * 0.11 * SR)
        m = int(1.0 * SR)
        tt = t(1.0)
        tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)) * env(m, 0.004, 0.35)
        out[s:s + m] += tone[: len(out) - s]
    return echo(out, 0.16, 0.3, 3)


def burst():
    n = int(SR * 1.4)
    tt = t(1.4)
    whine = np.sin(2 * np.pi * np.cumsum(300 + 2500 * (tt / 1.4) ** 2) / SR) * np.clip(tt / 0.9, 0, 1) * (tt < 0.95)
    static = highpass(rng.standard_normal(n), 1200) * np.clip((tt - 0.85) * 4, 0, 1) * np.exp(-np.clip(tt - 0.95, 0, None) * 5)
    return whine * 0.5 + static * 0.6


# --- station ------------------------------------------------------------------------

def ui_click():
    n = int(SR * 0.05)
    return np.sin(2 * np.pi * 1900 * t(0.05)) * env(n, 0.001, 0.008) + highpass(rng.standard_normal(n), 3000) * env(n, 0.0005, 0.003) * 0.3


def ui_launch():
    n = int(SR * 0.5)
    tt = t(0.5)
    clunk = np.sin(2 * np.pi * 140 * tt) * env(n, 0.002, 0.06)
    rise = np.sin(2 * np.pi * np.cumsum(300 + 900 * tt) / SR) * env(n, 0.05, 0.2) * 0.4
    return clunk + rise


def blip():
    n = int(SR * 0.045)
    tt = t(0.045)
    sq = np.sign(np.sin(2 * np.pi * 620 * tt)) * env(n, 0.002, 0.02)
    return lowpass(sq, 3500)


# --- the console's machines (added after the others so their random draws come last) -------

def _knock(f, dur, decay, noise=0.4, hp=200):
    n = int(SR * dur)
    tt = t(dur)
    body = np.sin(2 * np.pi * f * tt) * env(n, 0.0008, decay)
    click = highpass(rng.standard_normal(n), hp) * env(n, 0.0003, decay * 0.25) * noise
    return body + click


def drum():
    return _knock(900, 0.06, 0.012, 0.8, 2500)


def punch():
    n = int(SR * 0.42)
    out = np.zeros(n)
    a = _knock(120, 0.2, 0.05, 0.9, 400)
    b = _knock(260, 0.18, 0.03, 1.2, 1500)
    out[:len(a)] += a
    s = int(0.11 * SR)
    out[s:s + len(b)] += b * 0.9
    rattle = highpass(rng.standard_normal(n), 3000) * env(n, 0.002, 0.04) * 0.25
    return out + rattle


def lever():
    n = int(SR * 1.3)
    out = np.zeros(n)
    k = _knock(90, 0.3, 0.08, 1.0, 300)
    out[:len(k)] += k
    hiss = bandpass(rng.standard_normal(n), 800, 6000) * np.clip(t(1.3) / 0.15, 0, 1) * np.exp(-t(1.3) * 2.2) * 0.5
    clank = _knock(180, 0.4, 0.12, 0.8, 600)
    s = int(0.55 * SR)
    out[s:s + len(clank)] += clank * 0.8
    return out + hiss


def thump():
    n = int(SR * 0.5)
    tt = t(0.5)
    low = np.sin(2 * np.pi * (70 + 40 * np.exp(-tt * 30)) * tt) * env(n, 0.002, 0.09)
    rattle = bandpass(rng.standard_normal(n), 1500, 5000) * env(n, 0.001, 0.03) * 0.4
    return low + rattle


def tear():
    n = int(SR * 0.45)
    tt = t(0.45)
    grain = (rng.random(n) < 0.05 + 0.25 * np.sin(np.pi * tt / 0.45)) * rng.standard_normal(n)
    return bandpass(grain, 1200, 7000) * np.sin(np.pi * tt / 0.45) ** 0.5


def paper():
    n = int(SR * 0.28)
    tt = t(0.28)
    return bandpass(rng.standard_normal(n), 900, 5000) * np.sin(np.pi * tt / 0.28) ** 2 * 0.6


def type_burst():
    n = int(SR * 0.32)
    out = np.zeros(n)
    for i in range(9):
        s = int((i * 0.034 + rng.random() * 0.006) * SR)
        k = _knock(1400 + rng.random() * 500, 0.03, 0.006, 1.0, 2000)
        out[s:s + len(k)] += k[: max(0, n - s)] * (0.6 + rng.random() * 0.4)
    return out


def switch():
    return _knock(1500, 0.05, 0.006, 1.2, 3000)


def crank():
    n = int(SR * 0.12)
    out = np.zeros(n)
    for i in range(3):
        s = int(i * 0.035 * SR)
        k = _knock(2200, 0.03, 0.004, 1.0, 3500)
        out[s:s + len(k)] += k[: max(0, n - s)]
    return out


def stamp():
    n = int(SR * 0.4)
    tt = t(0.4)
    return np.sin(2 * np.pi * (60 + 30 * np.exp(-tt * 40)) * tt) * env(n, 0.001, 0.07) + _knock(300, 0.4, 0.02, 0.6, 500)


def relay():
    return _knock(2600, 0.04, 0.003, 1.0, 4000)


def cover():
    n = int(SR * 0.3)
    out = np.zeros(n)
    k = _knock(500, 0.12, 0.02, 0.9, 1500)
    out[:len(k)] += k
    k2 = _knock(350, 0.12, 0.03, 0.7, 900)
    s = int(0.09 * SR)
    out[s:s + len(k2)] += k2 * 0.7
    return out


if __name__ == "__main__":
    write("amb_dive", amb_dive(), 0.6)
    write("amb_station", amb_station(), 0.5)
    write("launch", launch())
    write("jelly", jelly(), 0.5)
    write("sting", sting(), 0.6)
    write("crash", crash(), 0.7)
    write("lurker_wake", lurker_wake(), 0.7)
    write("strike", strike(), 0.8)
    write("valve", valve(), 0.6)
    write("laser", laser(), 0.5)
    write("exit", exit_chime(), 0.6)
    write("burst", burst(), 0.6)
    write("ui_click", ui_click(), 0.4)
    write("ui_launch", ui_launch(), 0.6)
    write("blip", blip(), 0.35)
    write("drum", drum(), 0.4)
    write("punch", punch(), 0.8)
    write("lever", lever(), 0.7)
    write("thump", thump(), 0.7)
    write("tear", tear(), 0.6)
    write("paper", paper(), 0.4)
    write("type", type_burst(), 0.4)
    write("switch", switch(), 0.45)
    write("crank", crank(), 0.4)
    write("stamp", stamp(), 0.8)
    write("relay", relay(), 0.35)
    write("cover", cover(), 0.6)
