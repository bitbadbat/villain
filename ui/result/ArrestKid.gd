extends Node2D

## 연행 장면 — **층간소음 빌런이 끌려가면 아이가 "뿌에엥" 울면서 뒤를 쫓아온다**(2026-10-11 팀 피드백: "연행될 때 애가 뿌에엥하는 것도 넣어야 겠다").
##  - 그림은 게임 속 아이(`Kid.tscn`)를 그대로 쓰고 **얼굴만 우는 얼굴**(`층간소음아이울음.png`)로 바꾼다
##  - 엄마 품의 작은 아이(리그의 `Carry`)를 숨기는 건 ArrestScene이 한다(아이가 둘로 보이면 안 된다)
##  - 자리·크기는 ArrestScene이 **같은 카메라로 투영**해서 매 프레임 넣어 준다 — 이 노드의 position = 아이 발밑(화면 좌표)
##  - 눈물 분수·울음 선·"뿌에엥" 글자는 코드로 그린다. ⚠️ 주아체에 기호 글리프가 거의 없어서 **글자만 폰트**, 물결·선은 직접 그린다
##  - 좌우: 아이 그림(Puppet)만 뒤집는다. 글자·눈물은 안 뒤집힌 화면 좌표(Fx)에 그려야 글자가 거울 글씨가 안 된다
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — ArrestScene이 preload해서 노드에 붙인다

const ResultSfx = preload("res://ui/result/ResultSfx.gd")
const FONT = preload("res://fonts/Jua-Regular.ttf")
## 울음소리 이름 — `Sound/result/kid_cry.ogg|wav|mp3`를 넣으면 울기 시작할 때 한 번 나온다(아직 파일 없음 — 없으면 조용히 넘어간다)
const CRY_SOUND := "kid_cry"
## 글자를 이 크기로 한 번 그리고 배율로 키운다(원근으로 크기가 매 프레임 조금씩 바뀌어도 글자가 덜컥거리지 않게)
const FONT_BASE := 64
## "뿌에엥" 글자 자리 후보(아이 키 단위, 아이 머리 가운데 기준) — x는 **뒤쪽(보는 쪽 반대)이 +**, y는 아래가 +.
## 앞 순서부터 본다: 머리 위 뒤쪽 > 머리 위 > 머리 위 앞쪽 > 뒤쪽 머리 높이 > 뒤쪽 낮게 > 앞쪽 낮게
const TEXT_SLOTS := [Vector2(0.35, -0.55), Vector2(0.0, -0.66), Vector2(-0.35, -0.55), Vector2(0.78, -0.12), Vector2(0.72, 0.3), Vector2(-0.78, 0.18)]

var kid_scene: PackedScene = preload("res://characters/floornoise/Kid.tscn")
## 우는 얼굴 — 게임 속 아이 머리(1374x1145)와 거의 같은 캔버스(1392x1130)라 배율은 평소 머리 그대로 쓴다(리그의 kid_cry_scale도 비어 있다)
var cry_face: Texture2D = preload("res://sprite/층간소음/층간소음아이울음.png")
var land_pose: PackedScene = preload("res://characters/floornoise/KidLandPose.tscn")
var peak_pose: PackedScene = preload("res://characters/floornoise/KidPeakPose.tscn")
## 우는 얼굴 그림 속 **두 눈 자리**(px) — 눈물 분수가 여기서 뿜어진다. [앞 눈(코 쪽), 뒤 눈(귀 쪽)]. ⚠️ 그림을 바꾸면 다시 잴 것
var cry_eyes: Array[Vector2] = [Vector2(1120, 700), Vector2(965, 672)]
## 우는 얼굴 그림 속 **입 자리**(px) — 울음 선이 여기서 앞으로 퍼진다
var cry_mouth: Vector2 = Vector2(1010, 900)
var cry_text: String = "뿌에엥"

## 칠해진 아이 그림 네모(Kid.tscn 좌표) — ArrestScene이 재서 `set_bounds()`로 넣는다. 키를 맞추는 기준
var _bounds: Rect2 = Rect2(-150, -155, 300, 295)
var _puppet: Node2D = null
var _kid: Node2D = null
var _head: Sprite2D = null
var _fx: Node2D = null
## 조각 이름 -> [제자리, 제각도] — 매 프레임 여기서 출발해 자세를 섞는다(섞은 값이 쌓이지 않게)
var _rest: Dictionary = {}
var _rest_face: Texture2D = null

# --- 매 프레임 ArrestScene이 넣어 주는 값 ---
## 아이 키(화면 px) / 발밑 그림자 반지름 / 보는 쪽(-1 = 왼쪽, 행렬이 가는 쪽)
var _px: float = 100.0
var _shadow: Vector2 = Vector2.ZERO
var _facing: float = -1.0
## 울기 시작하고 흐른 초(음수면 아직 안 운다) / 장면 시계(실제 초)
var _cry_t: float = -1.0
var _clock: float = 0.0
var _sounded: bool = false
## 글자가 피할 네모들(이 노드 좌표 — 경찰·두 사람의 머리)과 보이는 화면(같은 좌표). ArrestScene이 `set_layout_hints()`로 넣는다
var _avoid: Array = []
var _view: Rect2 = Rect2()
## 고른 글자 자리(TEXT_SLOTS 번호, -1 = 아직) — 한 번 고르면 안 바꾼다(글자가 이리저리 튀지 않게)
var _text_slot: int = -1
## 고른 자리의 글자 네모(이 노드 좌표, 꼬리 포함) — 거울전에서 다른 아이 글자가 이걸 피한다
var _text_box: Rect2 = Rect2()

func _ready() -> void:
	_puppet = Node2D.new()
	_puppet.name = "Puppet"
	add_child(_puppet)
	_kid = kid_scene.instantiate() as Node2D
	_puppet.add_child(_kid)
	_head = _kid.get_node_or_null("KidHead") as Sprite2D
	if _head != null:
		_rest_face = _head.texture
	for child in _kid.get_children():
		var part := child as Node2D
		if part != null:
			_rest[part.name] = [part.position, part.rotation]
	# 눈물·글자는 아이 그림보다 **나중에**(위에) 그린다
	_fx = FxLayer.new()
	_fx.name = "Fx"
	_fx.set("painter", _paint_fx)
	add_child(_fx)

## 아이 그림 뿌리 — ArrestScene이 칠해진 영역을 잴 때 쓴다
func kid_root() -> Node2D:
	return _kid

## 칠해진 아이 그림 네모(아이 좌표)를 받는다 — 발바닥 가운데가 인형 원점에 오게 옮긴다(눌릴 때 발밑이 축)
func set_bounds(bounds: Rect2) -> void:
	if bounds.size.y <= 1.0:
		return
	_bounds = bounds
	_kid.position = -Vector2(bounds.get_center().x, bounds.end.y)

## 글자가 피할 네모(다른 사람 얼굴)와 보이는 화면 — 둘 다 이 노드 좌표
func set_layout_hints(avoid: Array, view: Rect2) -> void:
	_avoid = avoid
	_view = view

## 아이 얼굴 네모(캔버스 좌표) — 다른 아이의 "뿌에엥"이 덮지 않게(거울전)
func head_box_global() -> Rect2:
	if _head == null or _head.texture == null:
		return Rect2()
	var c: Vector2 = _face_point(_head.texture.get_size() * 0.5, self)
	return Rect2(get_global_transform() * (c - Vector2(0.3, 0.28) * _px), Vector2(0.6, 0.56) * _px)

## 고른 "뿌에엥" 글자 네모(캔버스 좌표). 아직 안 골랐으면 빈 네모
func text_box_global() -> Rect2:
	if not _text_box.has_area():
		return Rect2()
	return Rect2(get_global_transform() * _text_box.position, _text_box.size)

## 한 프레임 — px = 아이 키(화면 px), shadow = 그림자 반지름, cry_t = 울기 시작하고 흐른 초(음수면 아직),
## clock = 장면 시계, walking = 행렬이 걷는 중인지, lurch = 밧줄이 홱 당겨져 휘청이는 정도(0~1)
func tick(px: float, shadow: Vector2, facing: float, cry_t: float, clock: float, walking: bool, lurch: float) -> void:
	_px = maxf(px, 1.0)
	_shadow = shadow
	_facing = -1.0 if facing < 0.0 else 1.0
	_cry_t = cry_t
	_clock = clock
	var crying: bool = cry_t >= 0.0
	if crying and not _sounded:
		_sounded = true
		ResultSfx.play(self, CRY_SOUND, -4.0)
	if _head != null:
		_head.texture = cry_face if crying and cry_face != null else _rest_face
	# --- 몸: 울 땐 제자리에서 발을 동동 구르고(빠르게), 안 울 땐 아장아장 따라 걷는다 ---
	var period: float = 0.28 if crying else 0.36
	var p: float = fposmod(clock / period, 1.0)
	var moving: bool = walking or crying
	# 한 발씩 번갈아 디딘다 — 디딜 때마다(반 박자) 몸이 살짝 솟았다 내려앉는다
	var step: float = absf(sin(p * TAU)) if moving else 0.0
	var contact: float = 1.0 - step
	var hop_h: float = 0.035 if crying else 0.02
	# 울기 시작한 순간 한 번 "팍" — 움찔 솟았다 내려앉는다
	var burst: float = _pulse(cry_t, 0.06, 6.0) if crying else 0.0
	var sx: float = 1.0 + 0.05 * contact * float(moving) - 0.06 * burst
	var sy: float = 1.0 - 0.06 * contact * float(moving) + 0.03 * step + 0.1 * burst
	# 흐느낌 — 몸이 잘게 들썩인다
	var sob: float = sin(clock * 37.0) * 0.005 * _px if crying else 0.0
	var k: float = _px / maxf(_bounds.size.y, 1.0)
	_puppet.position = Vector2(0.0, -step * hop_h * _px - burst * 0.05 * _px + sob)
	_puppet.scale = Vector2(k * sx * _facing, k * sy)
	# 몸을 좌우로 흔든다(떼쓰기) + 밧줄이 홱 당겨지면 쫓아오다 앞으로 휘청 — 보는 쪽으로 기운다
	var sway: float = sin(p * TAU) * deg_to_rad(5.0 if crying else 2.5) * float(moving)
	_puppet.rotation = sway + lurch * deg_to_rad(14.0) * _facing
	# --- 자세: 제자리(Kid.tscn)에서 출발해 조각별로 섞는다(섞은 값이 프레임마다 쌓이지 않게) ---
	for part_name in _rest:
		var part := _kid.get_node_or_null(NodePath(part_name)) as Node2D
		if part == null:
			continue
		var rest: Array = _rest[part_name]
		part.position = rest[0]
		part.rotation = rest[1]
	# 디딜 때 무릎을 굽힌다 — 착지 자세에서 **몸·머리만** 빌린다(발까지 섞으면 다리를 찢은 것처럼 벌어졌다, 실측)
	_put_pose(land_pose, clampf(contact * float(moving) * (0.45 if crying else 0.25) + lurch * 0.5, 0.0, 1.0), ["KidBody", "KidHead"])
	if crying:
		# 두 팔을 휘저으며 운다 — 만세 자세의 **손만** 빌려 올렸다 내렸다
		var arms_up: float = 0.55 + 0.45 * sin(p * TAU + 0.6) + 0.3 * burst
		_put_pose(peak_pose, clampf(arms_up, 0.0, 1.0), ["KidHandL", "KidHandR"])
	# 발 동동 — 한 발씩 들었다 내린다(아이 좌표, 발 크기 기준)
	var lift: float = 0.07 * _bounds.size.y * (1.4 if crying else 1.0)
	for i in 2:
		var foot := _kid.get_node_or_null("KidFootL" if i == 0 else "KidFootR") as Node2D
		if foot == null or not moving:
			continue
		var up: float = maxf(0.0, sin(p * TAU + PI * i))
		foot.position.y -= up * lift
		foot.rotation += up * deg_to_rad(-18.0)
	if _head != null and crying:
		# 고개를 뒤로 젖히고(턱이 들림 — 아이 그림은 오른쪽을 보므로 음수 각도) 덜덜 떤다
		_head.rotation += deg_to_rad(-10.0) + sin(clock * 41.0) * deg_to_rad(2.5) - burst * deg_to_rad(6.0)
	queue_redraw()
	_fx.queue_redraw()

## 자세 씬 하나를 weight만큼 섞는다(EndingKid·RunningKid와 같은 방법 — 조각은 이름으로 찾는다). only를 주면 그 조각만
func _put_pose(scene: PackedScene, weight: float, only: Array = []) -> void:
	if scene == null or weight <= 0.001:
		return
	var pose: Dictionary = BodyRig.read_pose(scene)
	for part_name in pose:
		if not only.is_empty() and not only.has(part_name):
			continue
		var part := _kid.get_node_or_null(NodePath(part_name)) as Node2D
		if part == null:
			continue
		var data: Array = pose[part_name]
		part.position = part.position.lerp(data[0] as Vector2, weight)
		part.rotation = lerp_angle(part.rotation, data[1] as float, weight)

## 발밑 그림자(ArrestScene.ShadowBlob과 같은 색·모양) — 아이 그림보다 먼저(아래에) 그린다
func _draw() -> void:
	if _shadow.x < 0.5 or _shadow.y < 0.3:
		return
	var pts := PackedVector2Array()
	for i in 24:
		var t: float = TAU * i / 24.0
		pts.append(Vector2(cos(t) * _shadow.x, sin(t) * _shadow.y))
	draw_colored_polygon(pts, Color(0.16, 0.11, 0.09, 0.27))

# ---------------------------------------------------------------- 눈물 · 울음 선 · 글자

## 우는 얼굴 그림 px -> Fx 좌표(화면 px, 이 노드 기준)
func _face_point(px_on_face: Vector2, canvas: Node2D) -> Vector2:
	var tex: Texture2D = _head.texture
	var local: Vector2 = px_on_face - (tex.get_size() * 0.5 if _head.centered else Vector2.ZERO) + _head.offset
	return canvas.to_local(_head.to_global(local))

func _paint_fx(canvas: Node2D) -> void:
	if _cry_t < 0.0 or _head == null or _head.texture != cry_face:
		return
	_paint_wail_lines(canvas)
	_paint_tears(canvas)
	_paint_text(canvas)

## 눈물 분수(만화의 "폭포 눈물") — 두 눈에서 물줄기가 양옆으로 낮은 포물선을 그리며 뿜어지고, 끝에서 방울이 뚝뚝 떨어진다.
## 앞 눈(코 쪽)은 보는 쪽으로, 뒤 눈은 반대쪽으로. 물줄기는 굵기가 줄어드는 원을 촘촘히 이어 그린다.
## 울음이 터질 때마다(약 0.9초) 물줄기가 확 길어졌다 잦아든다.
## (윤곽을 먼저 다 그리고 속을 그 위에 그려서, 겹친 원·방울이 한 줄기로 붙는다)
func _paint_tears(canvas: Node2D) -> void:
	var grow: float = clampf(_cry_t / 0.16, 0.0, 1.0)
	var wail: float = _pulse(fposmod(_cry_t, 0.9), 0.05, 4.0)
	var g: float = 6.0 * _px
	var blobs: Array = []   # [자리, 반지름, 진하기]
	var shines: Array = []  # 물줄기마다 윗면 반짝이 선(PackedVector2Array)
	for e in cry_eyes.size():
		var eye: Vector2 = _face_point(cry_eyes[e], canvas)
		var dir: float = _facing if e == 0 else -_facing
		# 앞 눈은 앞으로 솟구쳐 포물선, 뒤 눈은 뒤로 흘러내린다 — 옆얼굴이라 뒤로 솟구치면 머리카락 위를 지나가 머리띠처럼 보였다(실측)
		var v0 := (Vector2(dir * 1.35, -0.55) if e == 0 else Vector2(dir * 0.75, 0.15)) * _px
		# 물줄기 — 길이(시간으로 잰 포물선 길이)가 울음에 맞춰 늘었다 줄었다 한다
		var span: float = (0.34 + 0.08 * wail + 0.02 * sin(_clock * 19.0 + e * 2.0)) * grow
		# ⚠️ 원 간격이 반지름보다 멀면 **구슬 목걸이**처럼 끊겨 보인다(14개로 그렸다가 지적받음, 2026-10-11) — 촘촘히 겹쳐 한 줄기로
		var steps: int = 56
		var shine := PackedVector2Array()
		for i in steps + 1:
			var u: float = float(i) / steps
			var age: float = span * u
			var pos: Vector2 = eye + v0 * age + Vector2(0.0, 0.5 * g * age * age)
			var r: float = _px * lerpf(0.032, 0.016, u)
			blobs.append([pos, r, 1.0])
			if u > 0.08 and u < 0.8:
				shine.append(pos + Vector2(0.0, -0.4) * r)
		shines.append(shine)
		# 끝에서 떨어지는 방울 — 물줄기 끝의 속도로 출발해 떨어지며 작아진다
		var tip_age: float = span
		var tip: Vector2 = eye + v0 * tip_age + Vector2(0.0, 0.5 * g * tip_age * tip_age)
		var tip_v: Vector2 = v0 + Vector2(0.0, g * tip_age)
		for i in 3:
			var life: float = 0.32
			var a: float = fposmod(_cry_t / life + i / 3.0 + 0.5 * e, 1.0)
			var age2: float = a * life
			if age2 > _cry_t:   # 울기 시작하기 전에 떨어진 방울은 없다
				continue
			var p: Vector2 = tip + tip_v * age2 * 0.6 + Vector2(0.0, 0.5 * g * age2 * age2)
			blobs.append([p, _px * 0.02 * (1.0 - 0.4 * a), 1.0 - smoothstep(0.7, 1.0, a)])
	var line := Color(0.08, 0.13, 0.24)
	for b in blobs:
		if float(b[1]) > 0.4:
			canvas.draw_circle(b[0], float(b[1]) + maxf(_px * 0.009, 1.0), Color(line, float(b[2])))
	for b in blobs:
		if float(b[1]) > 0.4:
			canvas.draw_circle(b[0], float(b[1]), Color(0.62, 0.86, 1.0, float(b[2])))
	# 반짝이는 물줄기 윗면에 가는 선 하나로(원마다 찍으면 점선이 된다)
	for shine in shines:
		if (shine as PackedVector2Array).size() >= 2:
			canvas.draw_polyline(shine, Color(1, 1, 1, 0.75), maxf(_px * 0.008, 1.0), true)

## 울음 선 — 벌린 입 앞으로 부채꼴로 뻗는 짧은 선 네 가닥(만화의 "으앙" 선). 길이가 바들바들 떨린다
func _paint_wail_lines(canvas: Node2D) -> void:
	var mouth: Vector2 = _face_point(cry_mouth, canvas)
	var pop: float = clampf(_cry_t / 0.1, 0.0, 1.0)
	var width: float = maxf(_px * 0.016, 1.2)
	for i in 4:
		var deg: float = lerpf(-62.0, 18.0, i / 3.0)
		var ang: float = deg_to_rad(deg)
		var dir := Vector2(cos(ang) * _facing, sin(ang))
		var wob: float = 0.5 + 0.5 * sin(_clock * 31.0 + i * 1.9)
		var r0: float = _px * (0.17 + 0.02 * wob)
		var r1: float = r0 + _px * (0.09 + 0.05 * wob) * pop
		canvas.draw_line(mouth + dir * r0, mouth + dir * r1, Color(0.07, 0.07, 0.1), width, true)

## "뿌에엥" — 아이 머리 가까이에 한 글자씩 튀어나와 덜덜 떨린다. 울음이 한 번 터질 때마다(약 0.9초) 글자가 들썩인다.
## 마지막 글자 뒤로 물결 꼬리를 그린다(주아체에 "~"가 없을 수 있어 직접 그린다).
## 자리는 TEXT_SLOTS 중에서 **다른 사람 얼굴·아이 얼굴을 안 덮고 화면 안에 드는 곳**을 처음 울 때 한 번 골라 고정한다(`_pick_text_slot`)
func _paint_text(canvas: Node2D) -> void:
	var fs: float = _px * 0.3
	var base_scale: float = fs / FONT_BASE
	var head_c: Vector2 = _face_point(_head.texture.get_size() * 0.5, canvas)
	var wail: float = _pulse(fposmod(_cry_t, 0.9), 0.05, 5.0)
	var tilts: Array[float] = [-0.18, 0.06, 0.16]
	var sizes: Array[float] = [1.0, 0.9, 1.22]
	var lifts: Array[float] = [0.08, -0.06, 0.02]
	var chars := PackedStringArray()
	for i in cry_text.length():
		chars.append(cry_text.substr(i, 1))
	var widths: Array[float] = []
	var total: float = 0.0
	for i in chars.size():
		# 글자 사이를 조금 띄운다 — 붙이면 "에"의 세로획이 다음 글자에 묻혀 "어"로 읽혔다(실측)
		var w: float = FONT.get_string_size(chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BASE).x * float(sizes[i % sizes.size()]) * 1.08
		widths.append(w)
		total += w
	if _text_slot < 0:
		_text_slot = _pick_text_slot(head_c, Vector2(total * base_scale + fs * 0.9, fs * 1.35), total * base_scale)
	var slot: Vector2 = TEXT_SLOTS[_text_slot]
	var anchor: Vector2 = head_c + Vector2(-_facing * slot.x, slot.y) * _px
	var x: float = -total * 0.5
	var outline := Color(0.06, 0.08, 0.2)
	var fill := Color(0.9, 0.97, 1.0)
	var ascent: float = FONT.get_ascent(FONT_BASE)
	var last_pos := Vector2.ZERO
	var last_scale: float = 0.0
	for i in chars.size():
		var appear: float = _cry_t - 0.07 * i
		var w: float = widths[i]
		x += w * 0.5
		if appear > 0.0:
			var pop: float = _ease_out_back(clampf(appear / 0.18, 0.0, 1.0), 1.7)
			var size_k: float = float(sizes[i % sizes.size()])
			var jitter := Vector2(sin(_clock * 53.0 + i * 2.1), cos(_clock * 47.0 + i * 3.3)) * fs * 0.035
			var pos: Vector2 = anchor + Vector2(x * base_scale, float(lifts[i % lifts.size()]) * fs) + jitter
			var sc: float = base_scale * size_k * pop * (1.0 + 0.14 * wail)
			canvas.draw_set_transform(pos, float(tilts[i % tilts.size()]) + sin(_clock * 23.0 + i) * 0.04, Vector2(sc, sc))
			var gw: float = FONT.get_string_size(chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BASE).x
			var at := Vector2(-gw * 0.5, ascent * 0.38)
			canvas.draw_string_outline(FONT, at, chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BASE, 22, outline)
			canvas.draw_string(FONT, at, chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BASE, fill)
			last_pos = pos
			last_scale = sc
		x += w * 0.5
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 물결 꼬리 — 마지막 글자가 다 튀어나온 뒤에 글 끝(오른쪽)으로 늘어진다. 글자는 늘 왼쪽에서 오른쪽으로 읽으니 보는 쪽과 상관없다
	var tail_t: float = _cry_t - 0.07 * (chars.size() - 1) - 0.08
	if tail_t > 0.0 and last_scale > 0.0:
		var grow: float = clampf(tail_t / 0.15, 0.0, 1.0)
		var start: Vector2 = last_pos + Vector2(FONT_BASE * 0.55 * last_scale, FONT_BASE * 0.05 * last_scale)
		var length: float = fs * 0.75 * grow
		var amp: float = fs * 0.09
		var pts := PackedVector2Array()
		for j in 17:
			var u: float = j / 16.0
			pts.append(start + Vector2(length * u, sin(u * TAU * 1.5 + _clock * 14.0) * amp))
		if length > 1.0:
			canvas.draw_polyline(pts, outline, fs * 0.17, true)
			canvas.draw_polyline(pts, fill, fs * 0.07, true)

## 글자 자리 고르기 — 후보마다 글자 네모(꼬리 포함)가 피할 네모(남의 얼굴 + 아이 얼굴)와 겹치는 넓이,
## 화면 밖으로 나가는 넓이(3배 벌점)를 더해 가장 작은 곳. 0인 곳이 있으면 앞 순서(머리 위 뒤쪽)부터 고른다
func _pick_text_slot(head_c: Vector2, box_size: Vector2, text_w: float) -> int:
	var avoid: Array = _avoid.duplicate()
	avoid.append(Rect2(head_c - Vector2(0.3, 0.28) * _px, Vector2(0.6, 0.56) * _px))
	var best: int = 0
	var best_score: float = INF
	for i in TEXT_SLOTS.size():
		var slot: Vector2 = TEXT_SLOTS[i]
		var anchor: Vector2 = head_c + Vector2(-_facing * slot.x, slot.y) * _px
		# 글자는 anchor 가운데, 꼬리는 오른쪽으로 붙는다
		var box := Rect2(anchor - Vector2(text_w * 0.5 + 4.0, box_size.y * 0.5), box_size)
		var score: float = 0.0
		for r in avoid:
			var hit: Rect2 = box.intersection((r as Rect2).grow(6.0))
			score += hit.get_area()
		if _view.has_area():
			score += 3.0 * (box.get_area() - box.intersection(_view.grow(-8.0)).get_area())
		if score < best_score - 0.5:
			best_score = score
			best = i
			_text_box = box
		if score <= 0.5:
			_text_box = box
			return i
	return best

## 확 올라갔다 서서히 잦아드는 한 번의 출렁임(s < 0이면 0) — ArrestScene._pulse와 같은 모양
static func _pulse(s: float, rise: float, decay: float) -> float:
	if s < 0.0:
		return 0.0
	if s < rise:
		return sin(s / rise * PI * 0.5)
	return exp(-(s - rise) * decay)

static func _ease_out_back(u: float, s: float) -> float:
	var v: float = u - 1.0
	return 1.0 + (s + 1.0) * v * v * v + s * v * v

## 눈물·글자를 그리는 겹 — 아이 그림(Puppet)과 달리 안 뒤집혀서 글자가 거울 글씨가 안 된다
class FxLayer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
