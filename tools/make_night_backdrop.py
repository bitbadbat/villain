# -*- coding: utf-8 -*-
"""연행 장면 건물 그림(낮)을 **밤 그림**으로 굽는다(2026-10-11, 번화가 — 사용자: "밤이라 어둡고 네온 사인이랑 불빛이 많잖아").
낮 그림(ui/result/backdrops/)은 그대로 두고, 같은 크기의 `<이름>_밤.png`를 **sprite/result/연행배경/**에 만든다
(그림은 sprite 폴더에 — 사용자 2026-10-11). `.tres`(ArrestBackdropConfig)의 texture를 그 파일로 바꾸면 끝.

하는 일:
  0. 간판 다시 칠하기(RELABEL) — 학원·약국·미용실처럼 **상가 같은 간판을 게임 번화가의 술집 간판으로** 바꾼다
     (2026-10-11 팀 피드백: "너무 번화가 같지 않고 상가 같다 — 감성술집·이술·서울포차처럼"). 판을 새 색으로 덮고 게임 글꼴로 글자를 쓴다
  1. 벽·창틀·간판 테두리 = 남색으로 어둡게 곱한다(WALL_MUL)
  2. 간판(SIGNS 네모 안 전부) = 원래 색 그대로 — 불 켜진 라이트박스
  3. 위층 창문(WINDOW_ZONE 안 파란 덩어리) = 형광등 켜진 창. 몇 개는 꺼 두고 몇 개는 따뜻한 색(같은 그림이면 매번 같은 창)
  4. 1층 가게 안(INTERIORS 구역) = 가게 불빛(편의점 하양 / 치킨집 주황 / 노래방 보라)
  5. 켜진 것들을 두 번 흐리게 번져(가까운 빛 + 먼 빛) 더한다 — 간판 둘레 벽이 그 색으로 물든다

그림을 바꾸면 SIGNS·구역을 다시 잴 것(덩어리 찾기: 테두리(어두운 선)로 나뉜 밝은 영역 = 간판·창 한 칸).
  python -X utf8 tools/make_night_backdrop.py
"""
import os
import random
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui", "result", "backdrops")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprite", "result", "연행배경")
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts")

# 그림마다 한 벌. 좌표는 원본 그림 px (x0, y0, x1, y1)
SPECS = {
    "번화가_건물.png": {
        "out": "번화가_건물_밤.png",
        # 간판(라이트박스) — 네모 안을 통째로 켠다(글자 포함)
        "signs": [
            (366, 600, 1169, 674),   # 25 편의점 띠
            (641, 88, 893, 167),     # 왕대박포차(가운데 위, 원래 학원)
            (639, 215, 896, 300),    # 쌩맥주24시(가운데, 원래 PC방)
            (637, 348, 897, 434),    # 전포다찌(가운데, 원래 치킨)
            (636, 485, 899, 571),    # 감성술집(가운데 맨 아래 — 화면에 보임, 원래 미용실)
            (58, 200, 318, 269),     # 보드카페(왼쪽, 원래 미용실)
            (42, 318, 310, 394),     # 노래방(왼쪽)
            (28, 464, 302, 551),     # 이술(왼쪽 — 화면에 보임, 원래 약국)
            (28, 586, 305, 654),     # 서울포차(왼쪽 아래 차양 가게 — 화면에 보임, 원래 치킨)
            (1219, 200, 1480, 274),  # PC방(오른쪽)
            (1225, 320, 1494, 395),  # 술집(오른쪽, 원래 학원)
            (1234, 467, 1513, 556),  # 코인노래방(오른쪽, 원래 약국)
            (1239, 588, 1512, 664),  # 치킨(오른쪽, 원래 노래방)
        ],
        # 위층 창문을 찾는 구역 — 이 안의 파란 덩어리가 창 한 칸
        "window_zone": (0, 90, 1536, 600),
        # 1층 가게 안 — (구역, 불빛 색, 세기)
        "interiors": [
            ((380, 685, 1165, 895), (235, 245, 255), 1.0),   # 편의점(하얀 형광등)
            ((0, 700, 306, 900), (255, 190, 110), 1.0),      # 치킨집(주황)
            ((1235, 700, 1536, 900), (225, 110, 255), 1.0),  # 노래방(보라 네온)
        ],
        # 간판 다시 칠하기 — 네모(위 signs와 같은 판 안쪽), 글자, 판 색, 글자 색, 글자 테두리 색, 글꼴, 모양(flat / neon)
        # 게임 번화가(sprite/맵/번화가/)에 있는 간판들: 감성술집(분홍 띠)·이술(갈색 나무)·전포다찌(벽돌에 주황 네온)·세로 간판(쌩맥주24시·왕대박포차·코인노래방·술집·보드카페)
        # 노래방·PC방·25 편의점은 번화가에도 있어 그대로 둔다
        "relabel": [
            # ⚠️ 연행 장면 카메라는 건물 **아래쪽**만 잡는다 — 화면에 보이는 간판은 가운데 맨 아래(감성술집)·왼쪽 아래 둘(이술·서울포차)뿐이라
            # 팀이 콕 집은 셋을 그 자리에 둔다(2026-10-11). 위층 간판은 처음 0.2초쯤 먼 화면에서만 보인다
            dict(rect=(636, 485, 899, 571), text="감성술집", panel=(236, 64, 160), ink=(255, 255, 255), line=(110, 18, 72), font="Jua-Regular.ttf"),
            dict(rect=(28, 464, 302, 551), text="이술", panel=(74, 48, 32), ink=(252, 236, 200), line=(30, 18, 10), font="Jalnan2.ttf"),
            dict(rect=(28, 586, 305, 654), text="서울포차", panel=(206, 32, 38), ink=(255, 222, 70), line=(90, 10, 12), font="Jalnan2.ttf"),
            dict(rect=(637, 348, 897, 434), text="전포다찌", panel=(46, 24, 28), ink=(255, 236, 200), line=(255, 110, 40), font="CookieRun-Black.ttf", style="neon"),
            dict(rect=(641, 88, 893, 167), text="왕대박포차", panel=(250, 112, 30), ink=(255, 255, 255), line=(120, 40, 8), font="Jalnan2.ttf"),
            dict(rect=(639, 215, 896, 300), text="쌩맥주24시", panel=(255, 206, 40), ink=(214, 32, 32), line=(110, 50, 0), font="CookieRun-Black.ttf"),
            dict(rect=(58, 200, 318, 269), text="보드카페", panel=(60, 140, 222), ink=(255, 255, 255), line=(14, 50, 110), font="Jalnan2.ttf"),
            dict(rect=(1225, 320, 1494, 395), text="술집", panel=(28, 122, 62), ink=(255, 255, 255), line=(8, 50, 22), font="Jalnan2.ttf"),
            dict(rect=(1234, 467, 1513, 556), text="코인노래방", panel=(150, 40, 204), ink=(255, 244, 130), line=(60, 10, 90), font="CookieRun-Black.ttf"),
            dict(rect=(1239, 588, 1512, 664), text="치킨", panel=(232, 40, 46), ink=(255, 255, 255), line=(100, 10, 14), font="Jalnan2.ttf"),
        ],
        "window_on": 0.72,      # 켜진 창 비율
        "window_warm": 0.3,     # 켜진 창 중 따뜻한 색 비율
        "seed": 7,
    },
}

WALL_MUL = np.array([0.21, 0.23, 0.40])     # 벽을 이만큼 곱한다(남색 밤)
WINDOW_COOL = np.array([205, 228, 255])
WINDOW_WARM = np.array([255, 214, 150])
WINDOW_TINT = 0.38                          # 켜진 창을 불빛 색 쪽으로 이만큼
OFF_WINDOW_MUL = 0.75                       # 꺼진 창은 벽보다 조금 더 어둡게
GLOW_NEAR = (14, 0.5)                       # (반지름 px, 세기)
GLOW_FAR = (52, 0.3)
GLOW_ON_LIGHT = 0.25                        # 켜진 칸 위에는 번짐을 이만큼만 — 다 얹으면 간판 글자가 바랜다
DARK_LUM = 70                               # 이보다 어두우면 테두리 선


def components(solid, zone):
    """zone 안에서 solid(밝은 칸)끼리 이어진 덩어리들 — [(ys, xs)]"""
    x0, y0, x1, y1 = zone
    sub = solid[y0:y1, x0:x1]
    seen = np.zeros_like(sub, bool)
    out = []
    h, w = sub.shape
    for y in range(h):
        for x in np.nonzero(sub[y] & ~seen[y])[0]:
            if seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            ys, xs = [], []
            while q:
                cy, cx = q.popleft()
                ys.append(cy)
                xs.append(cx)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and sub[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            out.append((np.array(ys) + y0, np.array(xs) + x0))
    return out


def relabel(img, items):
    """간판 판을 새 색으로 덮고 글자를 가운데에 쓴다(판 높이의 76%, 폭의 90% 안에 들게 글자 크기를 맞춘다 — 원래 간판만큼 크게)"""
    out = img.copy()
    for it in items:
        x0, y0, x1, y1 = it["rect"]
        w, h = x1 - x0, y1 - y0
        draw = ImageDraw.Draw(out)
        draw.rectangle((x0, y0, x1, y1), fill=tuple(it["panel"]) + (255,))
        path = os.path.join(FONTS, it["font"])
        size = int(h * 0.8)
        while size > 10:
            font = ImageFont.truetype(path, size)
            bx = draw.textbbox((0, 0), it["text"], font=font, stroke_width=max(2, size // 12))
            if bx[2] - bx[0] <= w * 0.9 and bx[3] - bx[1] <= h * 0.76:
                break
            size -= 2
        stroke = max(2, size // 12)
        bx = draw.textbbox((0, 0), it["text"], font=font, stroke_width=stroke)
        pos = (x0 + (w - (bx[2] - bx[0])) / 2 - bx[0], y0 + (h - (bx[3] - bx[1])) / 2 - bx[1])
        if it.get("style") == "neon":
            # 네온 — 글자 색 번짐을 먼저 깔고(판 안에서만) 그 위에 밝은 심 + 색 테두리
            glow = Image.new("RGBA", out.size, (0, 0, 0, 0))
            ImageDraw.Draw(glow).text(pos, it["text"], font=font, fill=tuple(it["line"]) + (255,), stroke_width=stroke * 3, stroke_fill=tuple(it["line"]) + (255,))
            glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
            panel = out.crop((x0, y0, x1, y1))
            panel.alpha_composite(glow.crop((x0, y0, x1, y1)))
            out.paste(panel, (x0, y0))
            draw = ImageDraw.Draw(out)
        draw.text(pos, it["text"], font=font, fill=tuple(it["ink"]) + (255,), stroke_width=stroke, stroke_fill=tuple(it["line"]) + (255,))
    return out


def bake(name, spec):
    src = Image.open(os.path.join(ROOT, name)).convert("RGBA")
    src = relabel(src, spec.get("relabel", []))
    a = np.asarray(src).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    H, W = alpha.shape
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    solid = (alpha > 200) & (lum > DARK_LUM)

    night = rgb * WALL_MUL
    emit = np.zeros_like(rgb)       # 번질 빛
    in_sign = np.zeros((H, W), bool)
    lit_mask = np.zeros((H, W), bool)   # 스스로 빛나는 칸

    # 2. 간판
    for (x0, y0, x1, y1) in spec["signs"]:
        night[y0:y1 + 1, x0:x1 + 1] = rgb[y0:y1 + 1, x0:x1 + 1]
        emit[y0:y1 + 1, x0:x1 + 1] = rgb[y0:y1 + 1, x0:x1 + 1]
        in_sign[y0:y1 + 1, x0:x1 + 1] = True
        lit_mask[y0:y1 + 1, x0:x1 + 1] = True

    # 3. 위층 창문
    rnd = random.Random(spec["seed"])
    for ys, xs in components(solid & ~in_sign, spec["window_zone"]):
        if len(ys) < 300:
            continue
        mean = rgb[ys, xs].mean(0)
        if mean[2] < mean[0] + 30:     # 파란 유리만(벽·실외기 제외)
            continue
        if rnd.random() > spec["window_on"]:
            night[ys, xs] = rgb[ys, xs] * WALL_MUL * OFF_WINDOW_MUL
            continue
        tint = WINDOW_WARM if rnd.random() < spec["window_warm"] else WINDOW_COOL
        lit = rgb[ys, xs] * (1.0 - WINDOW_TINT) + tint * WINDOW_TINT
        night[ys, xs] = lit
        emit[ys, xs] = lit * 0.55
        lit_mask[ys, xs] = True

    # 4. 1층 가게 안 — 테두리 선과 벽 기둥(베이지)은 빼고 켠다
    for (x0, y0, x1, y1), color, power in spec["interiors"]:
        r, g, b = (rgb[y0:y1, x0:x1, i] for i in range(3))
        beige = (r > 200) & (g > 160) & (g < 210) & (b > 95) & (b < 150) & (r - b > 70)
        mask = solid[y0:y1, x0:x1] & ~beige & ~in_sign[y0:y1, x0:x1]
        c = np.array(color, np.float32)
        lit = rgb[y0:y1, x0:x1] * 0.78 + c * 0.22
        night[y0:y1, x0:x1][mask] = lit[mask] * power
        emit[y0:y1, x0:x1][mask] = (lit[mask] * 0.5 + c * 0.5) * 0.8
        lit_mask[y0:y1, x0:x1] |= mask

    # 5. 번짐 — 가까운 빛 + 먼 빛을 더한다(벽이 간판 색으로 물든다)
    emit_img = Image.fromarray(np.clip(emit, 0, 255).astype(np.uint8), "RGB")
    out = night.copy()
    keep = np.where(lit_mask, GLOW_ON_LIGHT, 1.0)[..., None]
    for radius, power in (GLOW_NEAR, GLOW_FAR):
        blur = np.asarray(emit_img.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32)
        out += blur * power * keep
    out = np.clip(out, 0, 255).astype(np.uint8)
    res = np.dstack([out, alpha.astype(np.uint8)])
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, spec["out"])
    Image.fromarray(res, "RGBA").save(path)
    print("saved", path)


if __name__ == "__main__":
    for name, spec in SPECS.items():
        bake(name, spec)
