#!/usr/bin/env python3
"""뮤직비디오 → 레벨 변환기 (하떨별).

영상을 읽어서
  1. 장면 전환(컷)을 찾고 가장 뚜렷한 것만 최대 5개(최소 간격 8초) 남긴다.
  2. 마디(기본 2초)마다 프레임 하나를 골라 별(드론) 좌표로 바꾼다.
     윤곽(가장자리)과 밝기 점수가 높은 칸을 엇갈린 격자에서 골라 점 개수를 제한하고(기본 240개),
     격자 간격 덕분에 점 사이 최소 거리가 보장된다.
  3. 앞뒤 프레임의 별을 최소 이동 매칭(헝가리안)으로 짝지어 같은 번호의 별이 부드럽게 움직이게 한다.
  4. 별마다 프레임 색을 뽑아 shapes.gd 의 PALETTE 색으로 맞춘다.
  5. levels/<이름>.json 에 키프레임, 컷, Track1 형식의 SECTIONS / EVENTS 를 쓴다.
     (scripts/video_level.gd 가 이 파일을 읽어 그림을 등록하고 Track1 과 같은 형식으로 돌려준다)

사용:
  python3 tools/video_to_level.py 영상.mp4 --name mv1 [--bpm 120] [--audio] [--preview-dir 폴더]

필요: ffmpeg, ffprobe, numpy, Pillow (scipy 가 있으면 매칭에 사용, 없으면 내장 헝가리안)
"""
import argparse
import colorsys
import json
import math
import os
import subprocess
import sys

import numpy as np

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:  # 미리보기만 못 만든다
    Image = None

try:
    from scipy.optimize import linear_sum_assignment as _scipy_lsa
except Exception:
    _scipy_lsa = None

# shapes.gd 의 PALETTE 와 같은 값
PALETTE = {
    "gold": "ffd36b",
    "amber": "ffae5c",
    "peach": "ffc9a3",
    "rose": "ff8fb8",
    "lavender": "b9a6ff",
    "ice": "9fe8ff",
    "mint": "9ff5d0",
    "white": "fff8ec",
}

AW, AH = 256, 144  # 분석 해상도 (16:9 가 아니어도 비율은 meta.aspect 로 따로 저장)


# ───────────────────────── 영상 읽기 ─────────────────────────
def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height:format=duration", "-of", "json", path],
        check=True, capture_output=True, text=True).stdout
    j = json.loads(out)
    st = j["streams"][0]
    return float(j["format"]["duration"]), int(st["width"]), int(st["height"])


def read_frames(path, fps):
    """fps 간격으로 AWxAH RGB 프레임을 모두 읽는다. (시간, uint8 배열) 목록."""
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-vf",
           f"fps={fps},scale={AW}:{AH}:flags=area", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = AW * AH * 3
    frames = []
    i = 0
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            break
        frames.append(((i + 0.5) / fps, np.frombuffer(buf, np.uint8).reshape(AH, AW, 3)))
        i += 1
    p.wait()
    if not frames:
        sys.exit("프레임을 읽지 못했습니다: " + path)
    return frames


# ───────────────────────── 장면 전환 ─────────────────────────
def frame_signature(rgb):
    small = rgb[::4, ::4].astype(np.float32)
    gray = small.mean(axis=2)
    # 밝기를 표준화한 구조(어두운 화면끼리 바뀌어도 잡히게)
    z = (gray - gray.mean()) / (gray.std() + 8.0)
    q = (small // 64).astype(int)  # 4x4x4 색 히스토그램
    idx = q[..., 0] * 16 + q[..., 1] * 4 + q[..., 2]
    hist = np.bincount(idx.ravel(), minlength=64).astype(np.float32)
    hist /= hist.sum()
    return gray, hist, z


def cut_scores(frames):
    """프레임마다 직전 프레임과의 장면 변화 점수 (0..1 근처)."""
    sigs = [frame_signature(f) for _, f in frames]
    sc = np.zeros(len(frames))
    for i in range(1, len(frames)):
        g0, h0, z0 = sigs[i - 1]
        g1, h1, z1 = sigs[i]
        pix = np.abs(g1 - g0).mean() / 255.0
        hist = np.abs(h1 - h0).sum() * 0.5
        struct = min(float(np.abs(z1 - z0).mean()), 2.0) / 2.0
        sc[i] = 0.25 * pix + 0.25 * hist + 0.5 * struct
    return sc


def pick_cuts(frames, scores, duration, max_cuts, min_gap, min_score):
    """점수가 높은 컷부터 고르되 서로 min_gap 이상, 곡 처음/끝에서 min_gap/2 이상 떨어지게."""
    # 국소 최대값만 후보로. 바로 앞 몇 프레임의 평균보다 확 튀어야 진짜 컷이다(움직임 많은 장면 대비).
    cand = []
    for i in range(1, len(scores) - 1):
        if scores[i] < scores[i - 1] or scores[i] < scores[i + 1]:
            continue
        lo = max(1, i - 8)
        base = np.median(np.concatenate([scores[lo:i], scores[i + 1:i + 9]])) if i > 1 else 0.0
        rel = scores[i] - base
        if rel >= min_score:
            cand.append((rel, frames[i][0] - 0.5 * (frames[1][0] - frames[0][0]), i))
    cand.sort(reverse=True)
    cuts = []
    for rel, t, i in cand:
        if t < min_gap * 0.5 or t > duration - min_gap * 0.5:
            continue
        if all(abs(t - c[0]) >= min_gap for c in cuts):
            cuts.append((t, rel))
        if len(cuts) >= max_cuts:
            break
    cuts.sort()
    return cuts


# ───────────────────────── 프레임 → 별 ─────────────────────────
def make_grid(cols, aspect):
    """엇갈린(육각) 격자. 좌표는 프레임 기준 0..1. 이웃 간격 = 1/cols (가로 기준)."""
    s = 1.0 / cols
    dy = s * math.sqrt(3) / 2 * aspect  # 세로 좌표는 높이 기준이므로 비율 보정
    pts = []
    row = 0
    y = dy * 0.5
    while y < 1.0:
        x = s * (0.75 if row % 2 else 0.25)
        while x < 1.0:
            pts.append((x, y))
            x += s
        y += dy
        row += 1
    return np.array(pts, np.float32)


def score_map(rgb):
    img = Image.fromarray(rgb).filter(ImageFilter.GaussianBlur(1.2)) if Image else None
    a = (np.asarray(img) if img is not None else rgb).astype(np.float32) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114], np.float32)
    gx = np.zeros_like(lum)
    gy = np.zeros_like(lum)
    gx[:, 1:-1] = lum[:, 2:] - lum[:, :-2]
    gy[1:-1, :] = lum[2:, :] - lum[:-2, :]
    edge = np.hypot(gx, gy)
    # 색 경계도 윤곽으로 본다
    cdiff = np.zeros_like(lum)
    cdiff[:, 1:-1] += np.abs(a[:, 2:] - a[:, :-2]).sum(axis=2)
    cdiff[1:-1, :] += np.abs(a[2:, :] - a[:-2, :]).sum(axis=2)
    e = edge + 0.35 * cdiff
    e /= max(np.percentile(e, 99), 1e-3)
    bright = np.clip(lum - lum.mean(), 0, None)
    bright /= max(bright.max(), 1e-3)
    s = np.clip(0.7 * np.clip(e, 0, 1) + 0.3 * bright, 0, 1)
    # 칸 하나 크기만큼 퍼뜨려 격자점이 가는 선을 놓치지 않게
    if Image:
        s = np.asarray(Image.fromarray((s * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)),
                       np.float32) / 255.0
    return s


def snap_palette(rgb):
    """프레임 색 → 팔레트 이름. 채도가 낮으면 흰색, 아니면 색상(hue)이 가장 가까운 색."""
    r, g, b = [c / 255.0 for c in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.18 or v < 0.08:
        return "white"
    best, bd = "white", 9.0
    for name, hx in PALETTE.items():
        if name == "white":
            continue
        pr, pg, pb = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        ph, ps, _ = colorsys.rgb_to_hsv(pr, pg, pb)
        dh = abs(h - ph)
        dh = min(dh, 1 - dh) * 2  # 0..1
        d = dh * 1.0 + abs(min(s, 0.7) - ps) * 0.35
        if d < bd:
            best, bd = name, d
    return best


def frame_to_stars(rgb, grid, n, prev_sel=None, floor=0.06):
    """격자점 중 점수 상위 n 개를 고른다. 직전 키프레임에서 고른 칸은 가산점(깜빡임 방지)."""
    s = score_map(rgb)
    px = np.clip((grid[:, 0] * AW).astype(int), 0, AW - 1)
    py = np.clip((grid[:, 1] * AH).astype(int), 0, AH - 1)
    sc = s[py, px].copy()
    if prev_sel is not None:
        keep = prev_sel[sc[prev_sel] > floor]  # 지금도 그림이 있는 칸만 (지나간 자리에 별이 남지 않게)
        sc[keep] += 0.08
    order = np.argsort(-sc, kind="stable")
    good = order[sc[order] > floor]
    if len(good) >= n:
        sel = good[:n]
    elif len(good) > 0:
        # 그릴 게 적은 프레임: 고른 점을 겹쳐 채운다(같은 자리에 별이 겹침)
        sel = np.resize(good, n)
    else:
        sel = order[:n]
    pts = grid[sel].copy()
    # 색: 점 주변 3x3 평균
    cols = []
    for x, y in zip(px[sel], py[sel]):
        patch = rgb[max(0, y - 1):y + 2, max(0, x - 1):x + 2].reshape(-1, 3).mean(axis=0)
        cols.append(snap_palette(patch))
    return pts, cols, sel


# ───────────────────────── 매칭 ─────────────────────────
def lsa(cost):
    """정사각 비용 행렬의 최소 합 배정. 반환: row -> col."""
    if _scipy_lsa is not None:
        r, c = _scipy_lsa(cost)
        out = np.empty(len(r), int)
        out[r] = c
        return out
    n = cost.shape[0]
    INF = 1e18
    u = np.zeros(n + 1)
    v = np.zeros(n + 1)
    p = np.zeros(n + 1, int)
    way = np.zeros(n + 1, int)
    for i in range(1, n + 1):
        p[0] = i
        j0 = 0
        minv = np.full(n + 1, INF)
        used = np.zeros(n + 1, bool)
        while True:
            used[j0] = True
            i0 = p[j0]
            cur = cost[i0 - 1] - u[i0] - v[1:]
            free = ~used[1:]
            upd = free & (cur < minv[1:])
            minv[1:][upd] = cur[upd]
            way[1:][upd] = j0
            mv = np.where(free, minv[1:], INF)
            j1 = int(np.argmin(mv)) + 1
            delta = mv[j1 - 1]
            u[p[used]] += delta
            v[used] -= delta
            minv[~used] -= delta
            j0 = j1
            if p[j0] == 0:
                break
        while True:
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            if j0 == 0:
                break
    out = np.empty(n, int)
    for j in range(1, n + 1):
        out[p[j] - 1] = j - 1
    return out


def match(prev, cur, aspect):
    """cur 를 prev 의 별 순서에 맞게 다시 줄 세운 인덱스."""
    a = prev.copy()
    b = cur.copy()
    a[:, 1] /= aspect
    b[:, 1] /= aspect
    d = ((a[:, None, :] - b[None, :, :]) ** 2).sum(axis=2)
    return lsa(d)


# ───────────────────────── 이벤트 ─────────────────────────
def lerp(a, b, t):
    return a + (b - a) * t


def build_events(scenes, length, hold, t0, mode, keys_by_scene, all_keys, size):
    ev = []
    walls = ["left", "top", "right", "bottom"]
    emits = ["spiral", "rings", "flower"]
    wi = ei = 0
    end_t = length - 4.0 if length > 16 else length - 1.0
    if mode == "song":
        # 곡 전체를 한 무리가 맡는다. 마디마다 다음 키프레임으로 바뀌고, 컷에서는 snap 으로 확 흩어졌다 모인다.
        npath = max(3, int(length / 8))
        path = [[round(0.5 + 0.04 * math.sin(i * 1.7), 3), round(0.5 + 0.03 * math.cos(i * 1.3), 3)]
                for i in range(npath)]
        path[0] = path[-1] = [0.5, 0.5]
        ev.append({"t": t0, "type": "formation", "name": "V", "keys": all_keys, "hold": hold,
                   "dur": round(end_t - t0, 3), "size": size, "rot": 0.0, "big": 0.03, "fire": 3.0,
                   "exit": "scatter", "path": path})
    for si, sc in enumerate(scenes):
        a, b, e = sc["t"], sc["end"], sc["energy"]
        name = "V"
        if mode == "scene":
            name = "S%d" % (si + 1)
            ev.append({"t": round(max(a, t0), 3), "type": "formation", "name": name,
                       "keys": keys_by_scene[si], "hold": hold, "dur": round(min(b, end_t) - max(a, t0), 3),
                       "size": size, "rot": 0.0, "big": 0.03, "fire": round(lerp(4.0, 2.2, e), 2),
                       "exit": "collapse" if si < len(scenes) - 1 else "scatter",
                       "path": [[0.5, 0.5], [0.47, 0.49], [0.53, 0.51], [0.5, 0.5]]})
        if si > 0:
            ev.append({"t": round(a + (0.05 if mode == "scene" else 0.0), 3), "type": "snap", "at": name,
                       "power": round(lerp(450, 800, e)), "ring": int(lerp(56, 100, e)),
                       "waves": 2 if e > 0.5 else 1})
        # 공격: 밀도(energy)가 높을수록 자주, 세게. 컷 1.5초 전부터는 비워 둔다.
        period = hold * round(lerp(4, 2, e))
        t = a + (4.0 if si == 0 else 2.0 * hold)
        k = 0
        while t < min(b, end_t) - 1.5:
            if k % 2 == 0:
                kind = emits[ei % 3]
                ei += 1
                d = {"t": round(t, 3), "type": "emit", "kind": kind, "at": name,
                     "dur": round(min(hold * 2, b - t - 1.0), 2), "speed": round(lerp(135, 175, e))}
                if kind == "rings":
                    d.update({"rate": 1.0, "count": int(lerp(56, 88, e))})
                else:
                    d.update({"arms": int(lerp(4, 6, e)), "rate": round(lerp(0.16, 0.11, e), 3)})
                ev.append(d)
            else:
                ev.append({"t": round(t, 3), "type": "wall", "side": walls[wi % 4],
                           "gaps": 2 if e < 0.5 else 1, "speed": round(lerp(165, 210, e))})
                wi += 1
            t += period
            k += 1
    ev.append({"t": round(end_t, 3), "type": "clear"})
    ev.sort(key=lambda d: d["t"])
    return ev


# ───────────────────────── 미리보기 ─────────────────────────
def render_preview(path, rgb, pts, cols, aspect):
    W = 480
    H = int(W / aspect)
    im = Image.new("RGB", (W * 2 + 12, H), (0, 0, 0))
    im.paste(Image.fromarray(rgb).resize((W, H)), (0, 0))
    dr = ImageDraw.Draw(im)
    r = max(2, W // 160)
    for (x, y), c in zip(pts, cols):
        hx = PALETTE[c]
        col = tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))
        cx, cy = W + 12 + x * W, y * H
        dr.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=tuple(v // 4 for v in col))
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    im.save(path)


# ───────────────────────── 메인 ─────────────────────────
def main():
    ap = argparse.ArgumentParser(description="뮤직비디오 → 하떨별 레벨 JSON")
    ap.add_argument("video")
    ap.add_argument("--name", help="레벨 이름 (기본: 파일 이름)")
    ap.add_argument("--title", help="곡 제목 (기본: 이름)")
    ap.add_argument("--out-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "levels"))
    ap.add_argument("--bpm", type=float, default=120.0, help="곡 BPM. 한 마디(4박)마다 그림이 바뀐다")
    ap.add_argument("--hold-beats", type=float, default=4.0, help="키프레임 하나가 머무는 박 수 (기본 4 = 120BPM 에서 2초)")
    ap.add_argument("--offset", type=float, default=0.0, help="첫 박이 시작되는 시각(초)")
    ap.add_argument("--max-cuts", type=int, default=5)
    ap.add_argument("--min-gap", type=float, default=8.0, help="컷 사이 최소 간격(초)")
    ap.add_argument("--cut-score", type=float, default=0.12,
                    help="컷으로 볼 최소 장면 변화 점수(주변 프레임보다 튀는 정도, 0..1)")
    ap.add_argument("--stars", type=int, default=240, help="키프레임당 별 개수 상한 (피할 수 있게 260 이하 권장)")
    ap.add_argument("--cols", type=int, default=36, help="격자 가로 칸 수. 별 사이 최소 간격 = 화면 너비 / cols")
    ap.add_argument("--size", type=float, default=0.86, help="무리 크기 (구역 너비 대비)")
    ap.add_argument("--mode", choices=["song", "scene"], default="song",
                    help="song: 곡 전체 한 무리(컷마다 같은 별이 새 그림으로 몰려감), scene: 장면마다 새 무리")
    ap.add_argument("--fps", type=float, default=4.0, help="분석 fps")
    ap.add_argument("--audio", action="store_true", help="음악을 music/<이름>.ogg 로 뽑기")
    ap.add_argument("--preview-dir", help="장면별 미리보기 PNG 폴더")
    args = ap.parse_args()

    name = args.name or os.path.splitext(os.path.basename(args.video))[0]
    duration, vw, vh = probe(args.video)
    aspect = vw / vh
    print(f"[1/5] 영상 {args.video}: {duration:.1f}초 {vw}x{vh}")

    frames = read_frames(args.video, args.fps)
    scores = cut_scores(frames)
    cuts = pick_cuts(frames, scores, duration, args.max_cuts, args.min_gap, args.cut_score)
    hold = 60.0 / args.bpm * args.hold_beats
    t0 = args.offset
    # 컷을 마디 경계에 맞춘다 (그림이 바뀌는 순간 = 컷 = 박자)
    qcuts = []
    for t, rel in cuts:
        q = t0 + round((t - t0) / hold) * hold
        if q > t0 and q < duration and all(abs(q - c) > 1e-6 for c in qcuts):
            qcuts.append(round(q, 3))
    print(f"[2/5] 컷 {len(cuts)}개: " + ", ".join(f"{t:.2f}s(점수 {r:.2f})→{q:.2f}s" for (t, r), q in zip(cuts, qcuts)))

    bounds = [0.0] + qcuts + [duration]
    raw_bounds = [0.0] + [c[0] for c in cuts] + [duration]
    n_kf = max(1, int(math.floor((duration - t0) / hold)))
    grid = make_grid(args.cols, aspect)
    n = min(args.stars, int(len(grid) * 0.6))
    ftimes = np.array([f[0] for f in frames])

    def frame_at(t):
        return frames[int(np.argmin(np.abs(ftimes - t)))][1]

    def scene_of(t):
        for i in range(len(bounds) - 1):
            if bounds[i] - 1e-6 <= t < bounds[i + 1] - 1e-6:
                return i
        return len(bounds) - 2

    keyframes = []
    prev_pts = prev_sel = None
    prev_scene = -1
    disp_in, disp_cut = [], []
    for k in range(n_kf):
        ks = t0 + k * hold
        si = scene_of(ks + 1e-3)
        # 마디 앞쪽 1/3 지점 프레임을 쓰되, 원래(마디 맞추기 전) 장면 구간 안쪽으로 당긴다
        ra, rb = raw_bounds[si], raw_bounds[si + 1]
        st = min(max(ks + hold * 0.33, ra + 0.3), rb - 0.3)
        rgb = frame_at(st)
        pts, cols, sel = frame_to_stars(rgb, grid, n, prev_sel if si == prev_scene else None)
        if prev_pts is not None:
            perm = match(prev_pts, pts, aspect)
            pts = pts[perm]
            cols = [cols[j] for j in perm]
            d = np.hypot(pts[:, 0] - prev_pts[:, 0], (pts[:, 1] - prev_pts[:, 1]) / aspect)
            (disp_in if si == prev_scene else disp_cut).append(d)
        keyframes.append({"t": round(ks, 3), "src_t": round(st, 3), "scene": si,
                          "points": [[round(float(x), 4), round(float(y), 4)] for x, y in pts],
                          "colors": cols, "_rgb": rgb})
        prev_pts, prev_sel, prev_scene = pts, sel, si
    print(f"[3/5] 키프레임 {len(keyframes)}개 × 별 {n}개 (격자 {len(grid)}칸, 최소 간격 {1.0 / args.cols:.4f} 화면 너비)")

    # 장면 정보: 움직임(프레임 차이) + 그림 밀도로 세기(energy) 0..1
    scenes = []
    for i in range(len(bounds) - 1):
        a, b = bounds[i], bounds[i + 1]
        m = (ftimes >= a) & (ftimes < b)
        motion = float(scores[m].mean()) if m.any() else 0.0
        kfs = [kf for kf in keyframes if kf["scene"] == i]
        uniq = np.mean([len({tuple(p) for p in kf["points"]}) / n for kf in kfs]) if kfs else 0.5
        mean_rgb = np.mean([kf["_rgb"].reshape(-1, 3).mean(axis=0) for kf in kfs], axis=0) if kfs else np.zeros(3)
        scenes.append({"t": round(a, 3), "end": round(b, 3), "motion": motion, "fill": float(uniq),
                       "mean_rgb": mean_rgb})
    mmax = max(s["motion"] for s in scenes) or 1.0
    for s in scenes:
        s["energy"] = round(float(np.clip(0.6 * s["motion"] / mmax + 0.4 * s["fill"], 0, 1)), 3)

    keys_by_scene = [[f"vid_{name}_{k}" for k, kf in enumerate(keyframes) if kf["scene"] == i]
                     for i in range(len(scenes))]
    all_keys = [f"vid_{name}_{k}" for k in range(len(keyframes))]
    events = build_events(scenes, duration, hold, t0, args.mode, keys_by_scene, all_keys, args.size)

    sections = []
    for i, s in enumerate(scenes):
        c = s["mean_rgb"] / 255.0
        bg = "%02x%02x%02x" % tuple(int(8 + 40 * v) for v in c)  # 어두운 배경색
        sections.append({"t": s["t"], "name": f"장면 {i + 1}", "bg": bg})
    if duration > 16:
        sections.append({"t": round(duration - 4.0, 3), "name": "끝맺음", "bg": "05060f"})

    out = {
        "format": "hanulbyul-video-level", "version": 1,
        "meta": {"source": os.path.basename(args.video), "duration": round(duration, 3),
                 "width": vw, "height": vh, "aspect": round(aspect, 5), "bpm": args.bpm,
                 "hold": hold, "offset": t0, "stars": n, "cols": args.cols, "mode": args.mode,
                 "music": f"res://music/{name}.ogg" if args.audio else ""},
        "title": args.title or name, "length": round(duration, 3), "bpm": args.bpm,
        "world_wide": 1.0, "regions": {"full": [0, 0, 1, 1]}, "start_region": "full",
        "cuts": qcuts, "cuts_raw": [round(c[0], 3) for c in cuts],
        "scenes": [{k: v for k, v in s.items() if k != "mean_rgb"} for s in scenes],
        "keyframes": [{k: v for k, v in kf.items() if k != "_rgb"} | {"key": all_keys[i]}
                      for i, kf in enumerate(keyframes)],
        "sections": sections, "events": events,
    }
    os.makedirs(args.out_dir, exist_ok=True)
    jpath = os.path.abspath(os.path.join(args.out_dir, name + ".json"))
    with open(jpath, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"[4/5] {jpath} ({os.path.getsize(jpath) / 1024:.0f} KB, 이벤트 {len(events)}개)")

    def stat(ds):
        if not ds:
            return "없음"
        a = np.concatenate(ds)
        return f"평균 {a.mean():.4f}, 최대 {a.max():.4f}, 95% {np.percentile(a, 95):.4f}"
    print(f"      별 이동(화면 너비 비율) 장면 안: {stat(disp_in)} / 컷: {stat(disp_cut)}")

    if args.audio:
        mdir = os.path.join(os.path.dirname(jpath), "..", "music")
        os.makedirs(mdir, exist_ok=True)
        mp = os.path.abspath(os.path.join(mdir, name + ".ogg"))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", args.video, "-vn", "-c:a", "libvorbis",
                        "-q:a", "5", mp], check=True)
        print(f"      음악 → {mp}")

    if args.preview_dir and Image:
        os.makedirs(args.preview_dir, exist_ok=True)
        paths = []
        for i in range(len(scenes)):
            kfs = [kf for kf in keyframes if kf["scene"] == i]
            if not kfs:
                continue
            kf = kfs[len(kfs) // 2]
            p = os.path.join(args.preview_dir, f"{name}_scene{i + 1}.png")
            render_preview(p, kf["_rgb"], kf["points"], kf["colors"], aspect)
            paths.append(p)
        print("[5/5] 미리보기: " + ", ".join(paths))
    else:
        print("[5/5] 미리보기 생략")


if __name__ == "__main__":
    main()
