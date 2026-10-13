extends Node2D

## 연행 장면 구경꾼 한 명 — 게임 캐릭터처럼 **부위를 나눈 리그**(2026-10-11 사용자: "NPC들도 그렇게 하자 눈이랑 입이랑 몸이랑 손이랑
## 다 부위별로 나눠져 있어서 애니메이션 넣을 수도 있을 거 같은데?"). 통짜 그림일 땐 눈이 엉뚱한 데를 봐서 게임과 따로 놀았다.
## - 머리(얼굴 없는)·몸통·흰자·눈동자·감은 눈·눈썹·입 셋·소품은 사람마다 그린 그림(`sprite/result/구경꾼/<이름>/`),
##   **손·발은 게임 공용**(`sprite/body/손.png`·`발.png`, 발은 modulate로 신발 색) — 게임 캐릭터와 같은 몸으로 읽힌다
## - 원점 = 두 발 가운데 땅. 왼쪽(행렬 쪽)을 본다. 크기·자리·숨쉬기·폴짝·돌아보기는 `OnlookerCrowd`가 맡는다
## - 여기서는 리그 안 움직임만: 눈동자가 행렬을 따라감 / 저마다 다른 박자로 깜빡 / 입(평소·수군수군·놀람) /
##   "어? 나도?"(BEAT) 때 `react()` — 놀란 입 + 눈썹 번쩍 + 눈 커짐 / 소품 흔들기
## 씬의 조각 이름이 정해져 있다: Head/{HeadSprite, EyeL/{White/Pupil, WhiteLine, Closed}, EyeR/…, BrowL, BrowR, Mouth, Glasses?}, Body, HandL, HandR, FootL, FootR, Prop?
## 눈: 흰자(`White`, clip_children)가 홍채(`Pupil`)를 **흰자 모양으로 잘라** 옆을 볼 때 눈가에 살짝 가리고, 그 위에 흰자 테두리(`WhiteLine`)를 다시 얹는다.
## 시트의 까만 점 눈동자는 "동태 눈깔"(사용자 2026-10-11)이라 원래 그림처럼 갈색 홍채 + 하이라이트로 다시 그렸다
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — OnlookerCrowd가 노드로 부른다

## 입 그림 — 0 다문(평소) / 1 벌린 / 2 놀란
@export var mouths: Array[Texture2D] = []
@export var idle_mouth: int = 0
## 수군수군 — 켜면 가끔씩 입을 뻥끗거린다
@export var talk: bool = false
@export var talk_speed: float = 7.0
## "어? 나도?" 때 입과 그 표정이 가는 시간(초)
@export var react_mouth: int = 2
@export var react_time: float = 0.9
## 눈동자가 흰자 안에서 움직이는 거리(흰자 폭 대비) — 흰자 모양으로 잘리니 가장자리까지 가도 된다
@export var pupil_reach: float = 0.24
## 시선이 한 점에 박히지 않게 가끔 살짝 옮겨 보는 정도(pupil_reach 대비)와 그 사이(초)
@export var glance: float = 0.3
@export var glance_gap: Vector2 = Vector2(0.5, 1.4)
## 깜빡임 사이(초, 최소~최대)와 감고 있는 시간
@export var blink_gap: Vector2 = Vector2(1.8, 3.6)
@export var blink_time: float = 0.12
@export var seed_value: int = 1
## 소품 움직임
@export_enum("없음", "핸드폰 찍기", "지팡이 톡톡", "꼬치 까딱") var prop_motion: int = 0

var _head: Node2D
var _eyes: Array = []
var _brows: Array = []
var _mouth: Sprite2D
var _hands: Array = []
var _prop: Node2D
var _rest: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_blink: float = 0.0
var _blink_until: float = -1.0
var _react_at: float = -100.0
var _glance := Vector2.ZERO
var _next_glance: float = 0.0
var _time: float = 0.0
var _bounds: Rect2 = Rect2()

## 얼굴 조각은 장면의 윤곽광 재질을 안 받게 빈 재질을 미리 꽂아 둔다(눈·입 둘레에 빛 테가 생긴다)
static var _plain: CanvasItemMaterial = null

func _ready() -> void:
	_rng.seed = seed_value
	_next_blink = _rng.randf_range(0.3, blink_gap.y)
	_head = get_node_or_null("Head") as Node2D
	for eye_name in ["EyeL", "EyeR"]:
		var eye := get_node_or_null("Head/" + eye_name) as Node2D
		if eye != null:
			_eyes.append(eye)
	for brow_name in ["BrowL", "BrowR"]:
		var brow := get_node_or_null("Head/" + brow_name) as Node2D
		if brow != null:
			_brows.append(brow)
	_mouth = get_node_or_null("Head/Mouth") as Sprite2D
	for hand_name in ["HandL", "HandR"]:
		var hand := get_node_or_null(hand_name) as Node2D
		if hand != null:
			_hands.append(hand)
	_prop = get_node_or_null("Prop") as Node2D
	_bounds = _measure()
	for node in [_head, _prop] + _eyes + _brows + _hands:
		if node != null:
			_rest[node] = [node.position, node.rotation, node.scale]
	for eye in _eyes:
		var pupil := _pupil_of(eye)
		if pupil != null:
			_rest[pupil] = [pupil.position, pupil.rotation, pupil.scale]
	if _plain == null:
		_plain = CanvasItemMaterial.new()
	if _head != null:
		for child in _head.get_children():
			if child.name != "HeadSprite":
				_plain_material(child)
	_set_mouth(idle_mouth)

## 리그 좌표에서 그림이 차지하는 네모(쉬는 자세) — OnlookerCrowd가 키를 맞출 때 쓴다
func bounds() -> Rect2:
	return _bounds

## "어? 나도?" — 승자도 잡혀가는 순간 구경꾼이 놀란다
func react() -> void:
	_react_at = _time

## 한 프레임. t = 실제 시간(초), look_global = 바라볼 곳(전역 좌표, 행렬 가운데)
func tick(t: float, look_global: Vector2) -> void:
	_time = t
	var r: float = t - _react_at
	var reacting: bool = r >= 0.0 and r < react_time
	var shock: float = _bump(r, react_time) if reacting else 0.0
	# 눈 — 깜빡임
	if t >= _next_blink:
		_blink_until = t + blink_time
		_next_blink = t + _rng.randf_range(blink_gap.x, blink_gap.y)
	var closed: bool = t < _blink_until and not reacting
	# 가끔 시선을 살짝 옮긴다(행렬 안에서 이 사람 저 사람 보는 느낌)
	if t >= _next_glance:
		_glance = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.7, 0.7)) * glance
		_next_glance = t + _rng.randf_range(glance_gap.x, glance_gap.y)
	var look_local: Vector2 = to_local(look_global)
	for eye in _eyes:
		var white := eye.get_node_or_null("White") as Sprite2D
		var line := eye.get_node_or_null("WhiteLine") as CanvasItem
		var shut := eye.get_node_or_null("Closed") as Sprite2D
		var pupil := _pupil_of(eye)
		if white != null:
			white.visible = not closed
		if line != null:
			line.visible = not closed
		if shut != null:
			shut.visible = closed
		if pupil == null or white == null or white.texture == null:
			continue
		# 눈동자 — 행렬 쪽으로. 머리 좌표로 돌려서 잰다(머리가 기울어도 맞게).
		# 흰자의 자식이면 흰자 그림 px 단위, 아니면(옛 구조) 머리 단위라 흰자 배율을 곱한다
		var eye_local: Vector2 = to_local(eye.global_position)
		var dir: Vector2 = (look_local - eye_local).normalized() + _glance
		var reach: float = white.texture.get_width() * pupil_reach * (1.0 if pupil.get_parent() == white else absf(white.scale.x))
		var rest: Array = _rest[pupil]
		var head_rot: float = _head.rotation if _head != null else 0.0
		pupil.position = (rest[0] as Vector2) + dir.rotated(-head_rot) * reach * (1.0 - 0.5 * shock)
		# 놀라면 눈이 커지고 홍채는 작아진다
		pupil.scale = (rest[2] as Vector2) * (1.0 - 0.18 * shock)
		eye.scale = (_rest[eye][2] as Vector2) * (1.0 + 0.12 * shock)
	# 눈썹 — 놀라면 번쩍 올라간다
	for brow in _brows:
		var rest_b: Array = _rest[brow]
		brow.position = (rest_b[0] as Vector2) + Vector2(0.0, -2.2 * shock)
	# 입
	if reacting:
		_set_mouth(react_mouth)
	elif talk and sin(t * 1.3 + seed_value) > -0.1:
		_set_mouth(1 if fmod(t * talk_speed + seed_value * 0.37, 1.0) < 0.5 else idle_mouth)
	else:
		_set_mouth(idle_mouth)
	# 머리 — 행렬 쪽으로 살짝 + 놀라면 뒤로 움찔
	if _head != null:
		var rest_h: Array = _rest[_head]
		var nod: float = sin(t * 2.1 + seed_value) * 0.012
		_head.rotation = (rest_h[1] as float) + nod + deg_to_rad(5.0) * shock
		_head.position = (rest_h[0] as Vector2) + Vector2(0.0, -1.5 * shock)
	_move_prop(t, shock)

func _move_prop(t: float, shock: float) -> void:
	match prop_motion:
		1:
			# 핸드폰 찍기 — 손과 폰이 같이 살짝 흔들리고, 놀라면 폰을 번쩍 든다
			var shake := Vector2(sin(t * 3.1 + seed_value) * 0.6, sin(t * 4.3) * 0.5 - 3.0 * shock)
			for node in _hands + [_prop]:
				if node != null:
					node.position = (_rest[node][0] as Vector2) + shake
		2:
			# 지팡이 톡톡 — 1.6초마다 손이 지팡이를 들었다 놓는다
			var phase: float = fposmod(t + seed_value * 0.3, 1.6)
			var tap: float = sin(phase / 0.25 * PI) if phase < 0.25 else 0.0
			for node in [_hands[0] if not _hands.is_empty() else null, _prop]:
				if node != null:
					node.position = (_rest[node][0] as Vector2) + Vector2(0.0, -2.0 * tap - 1.5 * shock)
		3:
			# 꼬치 까딱 — 손목을 흔들 듯
			var wag: float = sin(t * 5.0 + seed_value) * 0.12 + 0.25 * shock
			if _prop != null:
				_prop.rotation = (_rest[_prop][1] as float) + wag
			if not _hands.is_empty():
				var hand: Node2D = _hands[0]
				hand.position = (_rest[hand][0] as Vector2) + Vector2(0.0, sin(t * 5.0 + seed_value) * 0.8 - 2.0 * shock)

static func _pupil_of(eye: Node) -> Node2D:
	var pupil := eye.get_node_or_null("White/Pupil") as Node2D
	return pupil if pupil != null else eye.get_node_or_null("Pupil") as Node2D

func _set_mouth(index: int) -> void:
	if _mouth == null or mouths.is_empty():
		return
	var tex: Texture2D = mouths[clampi(index, 0, mouths.size() - 1)]
	if tex != null and _mouth.texture != tex:
		_mouth.texture = tex

func _plain_material(node: Node) -> void:
	if node is CanvasItem and (node as CanvasItem).material == null:
		(node as CanvasItem).material = _plain
	for child in node.get_children():
		_plain_material(child)

## 보이는 그림 조각을 다 감싸는 네모(리그 좌표)
func _measure() -> Rect2:
	var out := Rect2()
	var found: bool = false
	var to_rig: Transform2D = get_global_transform().affine_inverse()
	for sprite in _sprites(self):
		if not sprite.is_visible_in_tree() or sprite.texture == null:
			continue
		var xf: Transform2D = to_rig * sprite.get_global_transform()
		var r: Rect2 = sprite.get_rect()
		var box := Rect2(xf * r.position, Vector2.ZERO)
		for corner in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			box = box.expand(xf * corner)
		out = box if not found else out.merge(box)
		found = true
	return out if found else Rect2(-20, -100, 40, 100)

static func _sprites(node: Node) -> Array:
	var list: Array = []
	for child in node.get_children():
		if child is Sprite2D:
			list.append(child)
		list.append_array(_sprites(child))
	return list

## 0에서 1로 부드럽게 올라갔다 내려오는 한 번(length초 동안). 범위 밖은 0
static func _bump(s: float, length: float) -> float:
	if s <= 0.0 or s >= length:
		return 0.0
	return sin(s / length * PI)
