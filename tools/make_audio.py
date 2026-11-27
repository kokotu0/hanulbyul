"""하떨별 임시 음악과 효과음을 합성한다. (모두 이 스크립트로 직접 만든 소리라 저작권 걱정 없음, CC0)

실행: python3 tools/make_audio.py   (numpy, ffmpeg 필요)
결과: music/track1.ogg, sfx/*.wav
곡 구조 (120 BPM, 한 마디 2초, 48마디 = 96초)
  0-8   도입      패드만
  8-32  집결      패드 + 아르페지오
  32-40 숨 고르기  패드 + 맥박
  40-64 결전      킥, 베이스, 빠른 아르페지오
  64-72 다리      킥 빠짐, 상승
  72-92 피날레    전부
  92-96 끝맺음    패드 잔향
"""
import os, subprocess, wave
import numpy as np

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
LEN = 96.0
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(7)

def hz(n):  # midi -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)

# Am - F - C - G (마디마다)
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
N = int(SR * LEN)
t_all = np.arange(N) / SR
mix = np.zeros(N)

def add(sig, start, gain=1.0):
    i = int(start * SR)
    if i >= N:
        return
    j = min(N, i + len(sig))
    mix[i:j] += sig[: j - i] * gain

def env_ad(n, a, d):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
    return e

def section(t):
    if t < 8: return "intro"
    if t < 32: return "A"
    if t < 40: return "break"
    if t < 64: return "B"
    if t < 72: return "bridge"
    if t < 92: return "fin"
    return "outro"

# ---- 패드: 마디마다 화음, 느린 어택, 살짝 디튠
for bar in range(48):
    t0 = bar * BAR
    ch = CHORDS[bar % 4]
    n = int(SR * (BAR + 1.2))
    tt = np.arange(n) / SR
    e = np.minimum(1, tt / 0.6) * np.minimum(1, np.maximum(0, (BAR + 1.2 - tt) / 1.0))
    sig = np.zeros(n)
    for note in ch + [ch[0] - 12]:
        for det in (-0.12, 0.12):
            f = hz(note + det)
            sig += np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)
    g = 0.035 if section(t0) not in ("B", "fin") else 0.03
    add(sig * e, t0, g)

# ---- 아르페지오 (플럭)
pluck_n = int(SR * 0.6)
def pluck(f, dec=0.25):
    tt = np.arange(pluck_n) / SR
    return (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * 2 * f * tt) * np.exp(-tt / 0.05)) * env_ad(pluck_n, 0.003, dec)

for bar in range(48):
    t0 = bar * BAR
    s = section(t0)
    if s in ("intro", "outro"):
        continue
    ch = CHORDS[bar % 4]
    seq = [ch[0], ch[1], ch[2], ch[1] + 12, ch[2] + 12, ch[1] + 12, ch[2], ch[1]]
    step = BEAT / 2 if s in ("A", "break", "bridge") else BEAT / 4
    count = int(BAR / step)
    for i in range(count):
        note = seq[i % len(seq)] + 12
        g = 0.09 if s != "break" else 0.05
        add(pluck(hz(note)), t0 + i * step, g)

# ---- 킥, 베이스, 하이햇
kick_n = int(SR * 0.35)
tk = np.arange(kick_n) / SR
kick = np.sin(2 * np.pi * np.cumsum(40 + 90 * np.exp(-tk / 0.04)) / SR) * np.exp(-tk / 0.12)
hat_n = int(SR * 0.05)
hat = rng.standard_normal(hat_n) * np.exp(-np.arange(hat_n) / SR / 0.012)
hat = np.diff(hat, prepend=0)
bass_n = int(SR * BEAT)
tb = np.arange(bass_n) / SR
for beat in range(int(LEN / BEAT)):
    t0 = beat * BEAT
    s = section(t0)
    bar = int(t0 // BAR)
    if s in ("B", "fin"):
        add(kick, t0, 0.5)
        add(hat, t0 + BEAT / 2, 0.08)
        f = hz(CHORDS[bar % 4][0] - 24)
        add(np.sin(2 * np.pi * f * tb) * env_ad(bass_n, 0.01, 0.25), t0, 0.22)
    elif s == "break":
        add(kick, t0, 0.18 if beat % 2 == 0 else 0)
    elif s == "bridge":
        add(hat, t0, 0.04 + 0.08 * (t0 - 64) / 8)
        add(hat, t0 + BEAT / 2, 0.04 + 0.08 * (t0 - 64) / 8)

# ---- 반짝이 (높은 종소리)
bell_n = int(SR * 1.5)
for i in range(70):
    t0 = rng.uniform(8, 92)
    ch = CHORDS[int(t0 // BAR) % 4]
    f = hz(rng.choice(ch) + 24)
    tt = np.arange(bell_n) / SR
    add(np.sin(2 * np.pi * f * tt) * env_ad(bell_n, 0.002, 0.5), t0, 0.04)

# 마무리: 끝 4초 페이드, 정규화
fade = np.clip((LEN - t_all) / 4, 0, 1)
mix *= np.minimum(1, t_all / 1.5) * np.where(t_all > 92, fade, 1)
mix = np.tanh(mix * 1.2)
mix = mix / np.max(np.abs(mix)) * 0.85

def write_wav(path, sig, sr=SR):
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data.tobytes())

os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
tmp = "/tmp/track1.wav"
write_wav(tmp, mix)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                os.path.join(ROOT, "music", "track1.ogg")], check=True)

# ---- 효과음
S = 22050
def tvec(sec): return np.arange(int(S * sec)) / S
sfx = {}
t = tvec(0.09); sfx["shot"] = np.sin(2 * np.pi * np.cumsum(1400 - 900 * t / 0.09) / S) * np.exp(-t / 0.03) * 0.5
t = tvec(0.12); sfx["hit"] = (np.sin(2 * np.pi * 300 * t) * 0.5 + rng.standard_normal(len(t)) * 0.3) * np.exp(-t / 0.03)
t = tvec(0.7)
noise = rng.standard_normal(len(t))
sfx["boom"] = (np.sin(2 * np.pi * np.cumsum(90 + 120 * np.exp(-t / 0.08)) / S) * 0.7 + np.convolve(noise, np.ones(8) / 8, "same") * 0.6) * np.exp(-t / 0.18)
t = tvec(0.45); sfx["hurt"] = (np.sign(np.sin(2 * np.pi * np.cumsum(500 - 700 * t) / S)) * 0.35) * np.exp(-t / 0.15)
t = tvec(1.6)
chime = np.zeros(len(t))
for k, n in enumerate([69, 73, 76, 81]):
    st = int(k * 0.12 * S)
    tt = t[: len(t) - st]
    chime[st:] += np.sin(2 * np.pi * hz(n) * tt) * np.exp(-tt / 0.5)
sfx["clear"] = chime * 0.35
t = tvec(0.25); sfx["click"] = np.sin(2 * np.pi * 880 * t) * np.exp(-t / 0.04) * 0.3
os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
for k, v in sfx.items():
    write_wav(os.path.join(ROOT, "sfx", k + ".wav"), v / max(1e-6, np.max(np.abs(v))) * 0.8, S)
print("ok")
