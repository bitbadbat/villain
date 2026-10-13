extends Resource

## 연행 장면 뒤에 서는 **건물 정면 그림 한 장 + 그 그림을 원근에 맞추는 표시**.
## 인물들이 이 건물 문에서 막 나온 것처럼 보이게, 장면이 **문**을 크기 기준점으로 삼아 그림을 놓는다:
## 문 아랫변이 장면의 "건물이 땅에 닿는 선"(ArrestScene.facade_base_y)에 오고, 문 높이가 캐릭터 키의 door_height배가 된다.
## 그래서 그림을 갈아 끼울 땐 **그림 속 문 자리(door_rect)만 재서 적으면** 크기·자리·밀고 들어가기가 저절로 맞는다.
## 새 그림을 그릴 땐 `ui/result/backdrops/원근가이드.png` 위에 그리면 지평선·소실점까지 맞는다.
## **맵마다 한 장**: 파일 이름이 맵 씬 이름과 같으면(헬스장 = maps/Gym.tscn → backdrops/Gym.tres) 그 맵에서 싸웠을 때 저절로 쓰인다.
## 그림(texture)을 비워 두면 기본 건물(경찰서)이 선다
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — .tres가 스크립트 경로로 물고 있다

## 건물 정면 그림(투명 배경 PNG — 하늘·앞길은 장면이 그린다)
@export var texture: Texture2D
## 그림 속 출입문 사각형(px). 크기가 0이면 "원근 가이드 위에 화면 그대로 그린 그림"으로 보고 화면에 1:1로 깐다
@export var door_rect: Rect2 = Rect2()
## 그림 속 건물이 땅(길)에 닿는 높이(px) — 이 아래는 잘라 낸다(앞길은 장면이 그린다). 0이면 그림 맨 아래,
## 문 자리 없이 가이드 위에 그린 그림이면 가이드의 초록 선
@export var ground_px: float = 0.0
## 문 높이 = 캐릭터 키의 몇 배인지(어린이 체형 캐릭터라 실제 비율보다 조금 크다)
@export var door_height: float = 1.35
## 그림이 그려진 눈높이(지평선, px). -1이면 모름 — 알면 장면 지평선과 어긋날 때 경고한다
@export var horizon_px: float = -1.0
## 경찰서 그림 전용 펄럭이는 깃발을 켤지(다른 건물이면 끈다)
@export var show_flags: bool = false
## 그림 가장자리를 하늘로 살짝 녹일지(잘린 건물 그림용)
@export var edge_fade: bool = true
## 밤 장면인지 — 켜면 장면이 건물 뒤에 **어두운 밤하늘**(남색 그라데이션 + 별 + 달)을 그린다.
## 그림에서 건물 사이사이를 투명하게 비워 두면 그 틈으로 밤하늘이 보여서 "밤"이라는 게 읽힌다(2026-10-11 번화가 — 감성 술집).
## 인물·앞길은 안 어두워진다
@export var night: bool = false
## 밤일 때 달도 띄울지
@export var night_moon: bool = true

@export_group("조명(인물·길)")
## 사람·경찰차·구경꾼에 곱할 빛 색 — 흰색이면 그대로, 밤이면 어둡게(건물 그림은 따로 밤 그림을 쓴다)
@export var ambient: Color = Color(1, 1, 1)
## 앞길(보도·도로)을 밤빛으로 얼마나 물들일지(`night`일 때만, ArrestBackdrop.night_ground_tint)
@export_range(0.0, 1.0, 0.01) var ground_tint: float = 0.16
## 인물 윤곽광(림) — 빛이 오는 쪽(인물 → 광원, 화면 기준)의 가장자리에 맺힌다
@export var rim_color: Color = Color(1.0, 0.96, 0.86)
@export var rim_dir: Vector2 = Vector2(-0.5, -1.0)
@export_range(0.0, 2.0, 0.01) var rim_strength: float = 0.35
## 빛을 정면으로 받는 가장자리만(1) ~ 옆면까지 넓게(0)
@export_range(0.0, 1.0, 0.01) var rim_focus: float = 0.55
## 광원 반대쪽 가장자리 그늘 / 파츠 안 위아래 명암
@export_range(0.0, 1.0, 0.01) var shade_strength: float = 0.25
@export_range(0.0, 0.5, 0.01) var gradient_strength: float = 0.08
## 경광등이 건물·길·인물을 물들이는 세기(낮에는 약하게, 밤에는 세게)
@export_range(0.0, 1.0, 0.01) var siren_power: float = 0.15
## 그림 속 불빛(간판·가게 창) — 그림 px 네모와 색(알파 = 세기). 길에 비친 빛과 1층 가게 불빛이 보도에 쏟아진 자리를 그린다
@export var light_rects: Array[Rect2] = []
@export var light_colors: PackedColorArray = PackedColorArray()
## 길에 비친 간판 빛의 세기(젖은 길처럼 세로로 길게) — 0이면 안 그린다
@export_range(0.0, 1.0, 0.01) var reflection: float = 0.0
## 화면 가장자리를 남색으로 어둡게(밤) — 0이면 안 그린다
@export_range(0.0, 1.0, 0.01) var vignette: float = 0.0
## 윤곽광 두께(화면 px)
@export_range(0.5, 8.0, 0.1) var rim_px: float = 2.2

@export_group("햇빛·그늘(낮 그림)")
## 건물 그림에 곱할 색 — 그림 맨 위 / 땅선. 위는 해를 받아 따뜻하게, 아래는 그늘로 푸르고 어둡게. 흰색이면 그대로
@export var facade_top: Color = Color(1, 1, 1)
@export var facade_bottom: Color = Color(1, 1, 1)
## 해 반대쪽(rim_dir 반대) 끝을 이만큼 어둡게 — 0이면 안 함
@export_range(0.0, 0.6, 0.01) var facade_side: float = 0.0
## 건물·나무 그늘이 앞길에 드리운 색(곱하기, 흰색이면 안 그림)과 깊이(월드, 캐릭터 키 = 1)
@export var ground_shade: Color = Color(1, 1, 1)
@export var ground_shade_depth: float = 1.0
## 햇살 색(알파 = 세기) — 빛줄기·땅의 햇빛 얼룩이 이 색
@export var sun_color: Color = Color(1.0, 0.88, 0.6, 0.0)
## 빛줄기(나무 틈으로 새는 햇살) — 그림 px (x, y, 폭). rim_dir 반대 방향(해에서 멀어지는 쪽)으로 뻗어 땅에 닿는다
@export var sun_shafts: Array[Vector3] = []
## 나뭇잎 사이 햇빛 얼룩 — 건물 앞 그늘 띠 안에 일렁이는 밝은 점(인물엔 안 얹는다 — 얼굴에 얼룩처럼 보였다). 0이면 안 함
@export_range(0.0, 1.0, 0.01) var dapple: float = 0.0
## 유리에 스치는 반짝임 — 그림 px 네모(유리창·유리문)와 한 번 스치는 간격(초)
@export var glint_rects: Array[Rect2] = []
@export var glint_period: float = 2.8
## light_rects를 그림 위에서도 빛나게(낮 그림용 — 밤 그림은 불이 구워져 있어 0)
@export_range(0.0, 1.0, 0.01) var light_glow: float = 0.0
## 모니터·TV처럼 깜빡이는 불 — light_rects 번호
@export var light_flicker: PackedInt32Array = PackedInt32Array()
