class_name SubwayVillainIdle
extends Control

## **지하철에 앉아 있는 지하철 아저씨** — 포토샵에서 쪼갠 여섯 장을 겹쳐 놓고 조각마다 따로 움직인다.
## 그림 한 장짜리 컷신이 아니라 "살아 있는 그림"이라, 대사 없이 걸어 둬도 화면이 안 죽는다.
##
## | 조각 | 움직임 |
## |---|---|
## | 몸통 | 숨쉬기(허리를 축으로 세로로 늘었다 줄었다) |
## | 단소 든 팔 | **위아래로 쾅 쾅** — 천천히 들었다 빠르게 내리꽂고 살짝 튄다 |
## | 머리 + 턱 괸 팔 | 좌우로 같이 흔들림(턱을 괴고 있으니 따로 놀면 안 된다) |
## | 머리카락 | 머리를 **한 박자 늦게** 따라 흔들림(한쪽만 — 2026-10-06 사용자: "귀찮아서 한쪽만") |
## | 배경 | 가만히 |
##
## 여섯 장 모두 **1140x1380 같은 캔버스**라, 전부 같은 자리에 겹쳐 놓으면 원본 그림이 된다.
## 그래서 조각마다 자리를 잡아 줄 필요가 없다 — 돌릴 축만 정해 주면 된다.
##
## ⚠️ **축은 `offset = -축` + `position = 축`으로 잡는다.** Sprite2D는 centered를 끄면 왼쪽 위를
## 중심으로 도는데, 머리카락을 그렇게 돌리면 화면 바깥을 축으로 빙 돌아 버린다

## 그림 조각들이 든 폴더
const DIR := "res://sprite/storymode/지하철빌런/"
## [노드 이름, 파일 이름] — **뒤에 적을수록 앞에 그려진다**(머리카락이 제일 앞)
const LAYERS: Array = [
	["Background", "지하철에앉아있는지하철빌런_0005_Background.png"],
	["Body", "지하철에앉아있는지하철빌런_0004_Layer-2.png"],
	["DansoArm", "지하철에앉아있는지하철빌런_0003_단소든팔.png"],
	["ChinArm", "지하철에앉아있는지하철빌런_0002_Layer-1.png"],
	["Head", "지하철에앉아있는지하철빌런_0001_머리.png"],
	["Hair", "지하철에앉아있는지하철빌런_0000_왼쪽머리카락.png"],
]
## 원본 캔버스 크기(여섯 장이 전부 같다)
const CANVAS := Vector2(1140.0, 1380.0)

@export_group("화면 채우기")
## **화면을 꽉 채운다**(2026-10-06 사용자 요청). 세로로 긴 그림이라 채우면 위아래가 잘리므로,
## 어디를 보여줄지는 아래 `focus_y`로 정한다. 끄면 그림 전체가 들어오게 줄인다(옆에 여백)
@export var fill_screen: bool = true:
	set(value):
		fill_screen = value
		_reframe()
## 화면 한가운데에 올 **원본 그림의 y**(px). 기본값은 머리에서 단소까지가 보이는 높이다
@export var focus_y: float = 430.0:
	set(value):
		focus_y = value
		_reframe()
## 화면 한가운데에 올 원본 그림의 x(px)
@export var focus_x: float = 570.0:
	set(value):
		focus_x = value
		_reframe()
## 채운 뒤 더 키우거나 줄일 배수
@export var zoom: float = 1.0:
	set(value):
		zoom = maxf(value, 0.05)
		_reframe()

@export_group("조각 갈아끼우기")
## **배경을 다른 그림으로 바꾼다**(2026-10-11). 비워 두면 원래 `_0005_Background`를 쓰는데,
## 그건 "배경만"이 아니라 **배경 + 인물 합본**이라 위에 올린 조각이 크게 움직이면
## 아래 원본 팔·다리가 드러난다. 인물을 지운 "좌석만" 그림을 여기 넣으면 그 문제가 없어진다
@export var background_texture: Texture2D = null:
	set(value):
		background_texture = value
		_swap_texture("Background", value, LAYERS[0][1])
## **다리 조각**(선택). 쪼개 둔 여섯 장에는 상반신만 있고 다리는 배경에만 그려져 있다 —
## 배경을 좌석만 있는 그림으로 바꾸려면 다리를 따로 받아야 한다. 배경 바로 위에 깔린다
@export var legs_texture: Texture2D = null:
	set(value):
		legs_texture = value
		_apply_legs()

@export_group("카메라 훑기")
## **아래에서 위로 천천히 훑는다**(2026-10-11 사용자 구상: "아래서부터 위로 보여줌").
## 움직이는 건 `focus_y` 하나뿐이라 **숨쉬기·단소 쾅쾅·흔들림은 그대로 돈다** — 그림을 통째로
## 미는 게 아니라 "어디를 보고 있는지"만 바꾸는 것이다.
## 0이면 안 훑고 `focus_y` 자리에 가만히 있는다
@export var pan_time: float = 0.0
## 훑기 시작할 때 화면 한가운데에 올 원본 y(px). 큰 값일수록 아래(발·단소 끝)를 본다.
## 끝나는 자리는 위의 `focus_y`다
@export var pan_from_y: float = 1060.0
## 훑기를 시작하기까지 기다리는 시간(초)
@export var pan_delay: float = 0.0

@export_group("숨쉬기")
## 한 번 숨쉬는 데 걸리는 시간(초)
@export var breath_cycle: float = 3.4
## 가슴이 부풀 때 세로로 늘어나는 비율(0.018 = 1.8%)
@export var breath_amount: float = 0.018
## 몸통이 늘어날 때 **고정될 자리**(허리). 여기를 축으로 어깨만 올라간다
@export var body_pivot: Vector2 = Vector2(450, 615)

@export_group("단소 쾅쾅")
## 한 번 내리치는 데 걸리는 시간(초)
@export var bang_cycle: float = 1.9
## 들어 올리는 높이(px, 원본 그림 기준). **음수가 위**다
@export var bang_lift: float = -34.0
## 치고 나서 튀어 오르는 높이(px)
@export var bang_rebound: float = 9.0
## 한 번 중에서 **드는 데 쓰는 몫**(나머지가 내리치고 튀는 시간). 클수록 천천히 들었다 확 내린다
@export_range(0.3, 0.95, 0.05) var bang_rise_ratio: float = 0.72
## 내리친 순간 **화면 전체가 같이 흔들리는** 세기(px). 0이면 안 흔든다
@export var bang_shake: float = 7.0
## 흔들림이 잦아드는 시간(초)
@export var bang_shake_time: float = 0.22
## 단소 든 팔이 도는 축(어깨)
@export var danso_pivot: Vector2 = Vector2(330, 300)

@export_group("좌우 흔들림")
## 머리·턱 괸 팔이 한 번 왕복하는 시간(초)
@export var sway_cycle: float = 4.6
## 좌우로 움직이는 폭(px)과 같이 기우는 각도(도)
@export var sway_amount: float = 7.0
@export var sway_tilt_deg: float = 1.4
## 머리가 도는 축(목)
@export var head_pivot: Vector2 = Vector2(530, 320)
## 턱 괸 팔이 도는 축(팔꿈치). 머리를 받치고 있어서 **같은 박자**로 움직인다
@export var chin_pivot: Vector2 = Vector2(770, 520)
## 턱 괸 팔이 머리를 따라가는 정도(1이면 똑같이)
@export var chin_follow: float = 0.75

@export_group("머리카락")
## 머리카락이 도는 축(머리에 붙은 자리)
@export var hair_pivot: Vector2 = Vector2(430, 110)
## 흔들리는 각도(도)와 한 번 왕복하는 시간(초)
@export var hair_swing_deg: float = 3.2
@export var hair_cycle: float = 2.3
## 머리를 **몇 초 늦게** 따라가는지. 늦어야 머리카락이 딸려 오는 것처럼 보인다
@export var hair_lag: float = 0.28

## 조각들을 담는 그릇 — 화면 채우기(배율·자리)는 이 노드 하나만 건드린다
var _frame: Node2D = null
## 이름으로 찾아 쓰는 조각들
var _parts: Dictionary = {}
## 흐른 시간(초)
var _time: float = 0.0
## 훑는 중 지금 보고 있는 원본 y. -1이면 아직 안 훑었다는 뜻이라 `focus_y`를 그대로 쓴다
var _pan_y: float = -1.0
## 내리친 뒤 남은 흔들림 시간
var _shake_left: float = 0.0
## 직전 프레임의 내리치기 진행도 — 0으로 넘어가는 순간이 "친 순간"이다
var _bang_prev: float = 0.0

func _ready() -> void:
	# 화면 전체를 덮지만 입력은 안 가로챈다(스토리 장면 위에 얹히는 그림이라)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	resized.connect(_reframe)
	_reframe()

## 여섯 장을 순서대로 쌓는다
func _build() -> void:
	_frame = Node2D.new()
	_frame.name = "Frame"
	add_child(_frame)
	for row in LAYERS:
		var sprite := Sprite2D.new()
		sprite.name = row[0]
		sprite.texture = load(DIR + row[1])
		sprite.centered = false
		_frame.add_child(sprite)
		_parts[row[0]] = sprite
	_set_pivot("Body", body_pivot)
	_set_pivot("DansoArm", danso_pivot)
	_set_pivot("ChinArm", chin_pivot)
	_set_pivot("Head", head_pivot)
	_set_pivot("Hair", hair_pivot)
	# 인스펙터에서 갈아 끼운 그림이 있으면 지금 반영한다(setter는 _build 전에 돌 수 있다)
	_swap_texture("Background", background_texture, LAYERS[0][1])
	_apply_legs()

## 조각 하나의 그림을 바꾼다. `value`가 비면 원래 파일로 되돌린다
func _swap_texture(part_name: String, value: Texture2D, fallback_file: String) -> void:
	var sprite: Sprite2D = _parts.get(part_name)
	if sprite == null:
		return
	sprite.texture = value if value != null else load(DIR + fallback_file)

## 다리 조각을 **배경 바로 위**(= 몸통보다 뒤)에 깐다. 앉아 있는 다리는 안 움직이므로
## 축도 안 잡는다 — 숨쉬기로 몸통이 늘어도 다리는 제자리에 있는 게 맞다
func _apply_legs() -> void:
	if _frame == null or not is_instance_valid(_frame):
		return
	var legs: Sprite2D = _parts.get("Legs")
	if legs_texture == null:
		if legs != null and is_instance_valid(legs):
			legs.queue_free()
			_parts.erase("Legs")
		return
	if legs == null or not is_instance_valid(legs):
		legs = Sprite2D.new()
		legs.name = "Legs"
		legs.centered = false
		_frame.add_child(legs)
		_frame.move_child(legs, 1)   # Background(0) 바로 뒤
		_parts["Legs"] = legs
	legs.texture = legs_texture

## 그 조각이 **그 점을 중심으로** 돌고 커지게 만든다
func _set_pivot(part_name: String, pivot: Vector2) -> void:
	var sprite: Sprite2D = _parts.get(part_name)
	if sprite == null:
		return
	sprite.offset = -pivot
	sprite.position = pivot

## 화면 크기에 맞춰 그릇의 배율·자리를 다시 잡는다
func _reframe() -> void:
	if _frame == null:
		return
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		view = Vector2(1280, 720)
	# 채우기 = 가로·세로 중 **큰 쪽**에 맞춘다(남는 쪽이 잘린다). 맞추기 = 작은 쪽
	var k: float = maxf(view.x / CANVAS.x, view.y / CANVAS.y) if fill_screen \
		else minf(view.x / CANVAS.x, view.y / CANVAS.y)
	k *= zoom
	_frame.scale = Vector2(k, k)
	# 보고 싶은 점(focus)이 화면 한가운데 오게 민다
	# 훑는 중이면 그 자리를, 아니면 인스펙터에 적힌 focus_y를 본다
	var look_y: float = _pan_y if pan_time > 0.0 and _pan_y >= 0.0 else focus_y
	_frame.position = view * 0.5 - Vector2(focus_x, look_y) * k

func _process(delta: float) -> void:
	_time += delta
	_pan()
	_breathe()
	_bang(delta)
	_sway()
	_shake(delta)

## 보는 자리를 `pan_from_y`에서 `focus_y`로 천천히 옮긴다.
## **`focus_y` 자체는 안 건드린다** — 그걸 바꾸면 setter가 돌면서 인스펙터 값이 덮어써진다
func _pan() -> void:
	if pan_time <= 0.0:
		return
	var t: float = clampf((_time - pan_delay) / pan_time, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)   # 천천히 시작해 천천히 멈춘다
	_pan_y = lerpf(pan_from_y, focus_y, t)
	_reframe()

## 몸통 숨쉬기 — 허리를 축으로 세로만 늘었다 줄었다
func _breathe() -> void:
	var body: Sprite2D = _parts.get("Body")
	if body == null:
		return
	var k: float = sin(_time * TAU / maxf(breath_cycle, 0.1)) * 0.5 + 0.5
	body.scale = Vector2(1.0, 1.0 + breath_amount * k)

## 단소를 든 팔 — **천천히 들었다 빠르게 내리꽂고 살짝 튄다.**
## 등속으로 오르내리면 "쾅"이 아니라 "둥실둥실"이 된다
func _bang(_delta: float) -> void:
	var arm: Sprite2D = _parts.get("DansoArm")
	if arm == null:
		return
	var span: float = maxf(bang_cycle, 0.2)
	var t: float = fposmod(_time, span) / span
	var rise: float = clampf(bang_rise_ratio, 0.3, 0.95)
	var y: float = 0.0
	if t < rise:
		# 드는 구간 — 끝에서 느려지게(사인 한 토막) 들어 올린다
		y = bang_lift * sin(t / rise * PI * 0.5)
	else:
		# 내리치는 구간 — 쭉 떨어졌다가 한 번 튄다
		var f: float = (t - rise) / (1.0 - rise)
		y = bang_lift * (1.0 - f) * (1.0 - f)
		if f > 0.55:
			y += bang_rebound * sin((f - 0.55) / 0.45 * PI)
	arm.position = danso_pivot + Vector2(0.0, y)
	# 한 바퀴를 돌아 처음으로 넘어가는 순간 = 바닥을 친 뒤다
	if _bang_prev > 0.3 and t < 0.1:
		_shake_left = bang_shake_time
	_bang_prev = t

## 머리·턱 괸 팔·머리카락 — 셋이 **같은 박자로** 흔들린다(머리카락만 한 박자 늦게)
func _sway() -> void:
	var k: float = sin(_time * TAU / maxf(sway_cycle, 0.1))
	var head: Sprite2D = _parts.get("Head")
	if head:
		head.position = head_pivot + Vector2(sway_amount * k, 0.0)
		head.rotation_degrees = sway_tilt_deg * k
	var chin: Sprite2D = _parts.get("ChinArm")
	if chin:
		# 턱을 괴고 있으니 머리를 따라간다 — 다만 팔꿈치가 무릎에 붙어 있어 덜 움직인다
		chin.position = chin_pivot + Vector2(sway_amount * k * chin_follow, 0.0)
		chin.rotation_degrees = sway_tilt_deg * k * chin_follow
	var hair: Sprite2D = _parts.get("Hair")
	if hair:
		var lag: float = sin((_time - hair_lag) * TAU / maxf(hair_cycle, 0.1))
		hair.position = hair_pivot + Vector2(sway_amount * k, 0.0)
		hair.rotation_degrees = hair_swing_deg * lag

## 내리친 순간의 화면 흔들림 — **그릇을 통째로** 흔든다(조각끼리 어긋나지 않게)
func _shake(delta: float) -> void:
	if _frame == null or _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var power: float = _shake_left / maxf(bang_shake_time, 0.01)
	_reframe()
	_frame.position += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * bang_shake * power
