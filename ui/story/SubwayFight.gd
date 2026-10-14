@tool
extends Node2D

## **지하철 전투 컷신**(2026-10-14 사용자: "지하철 전투 씬 1번"). 그림이 **부위별로** 나뉘어 있어서
## 어제 만든 격돌 컷신([[SubwayClash]])과 달리 팔·머리를 따로 흔들 수 있다.
##
## 겹치는 순서는 뒤에서부터 **배경 → 경찰 몸 → 경찰 팔 → 할아버지 하체 → 조끼 → 머리 → 팔(단소) → 속도선**.
## 레이어가 전부 **같은 캔버스(683x690)로 잘려 있어서** 그냥 겹치기만 하면 원본 그림이 된다 —
## 움직임만 얹으면 된다.
##
## 두 사람은 무기를 맞댄 채 **서로 밀어내듯 떨고**, 팔과 머리는 위상을 어긋나게 떨어 힘주는 느낌을 준다.
## 속도선은 깜빡이며 살짝 커진다.

@export_group("레이어")
@export var background_texture: Texture2D = null:
	set(value):
		background_texture = value
		_rebuild()
@export var police_body_texture: Texture2D = null:
	set(value):
		police_body_texture = value
		_rebuild()
@export var police_arm_texture: Texture2D = null:
	set(value):
		police_arm_texture = value
		_rebuild()
@export var villain_legs_texture: Texture2D = null:
	set(value):
		villain_legs_texture = value
		_rebuild()
@export var villain_vest_texture: Texture2D = null:
	set(value):
		villain_vest_texture = value
		_rebuild()
@export var villain_head_texture: Texture2D = null:
	set(value):
		villain_head_texture = value
		_rebuild()
@export var villain_arm_texture: Texture2D = null:
	set(value):
		villain_arm_texture = value
		_rebuild()
@export var speedline_texture: Texture2D = null:
	set(value):
		speedline_texture = value
		_rebuild()

@export_group("화면")
## 그림을 화면보다 이만큼 크게 그린다 — 흔들려도 가장자리가 안 드러나게
@export_range(1.0, 1.4, 0.01) var overscan: float = 1.1:
	set(value):
		overscan = value
		_rebuild()
## 그림을 화면 안에서 비켜 놓는다(px). 인물을 가운데에 두고 싶을 때
@export var art_offset: Vector2 = Vector2.ZERO:
	set(value):
		art_offset = value
		_rebuild()
## 배경이 천천히 다가오는 정도(0이면 안 움직인다)와 걸리는 시간(초)
@export var zoom_in: float = 0.06
@export var zoom_time: float = 4.0


@export_group("내려치기")
## **어깨 자리**(원본 그림 683x690 픽셀 기준). 팔이 이 점을 축으로 돈다 —
## 그림을 바꿨으면 여기도 다시 잴 것
@export var police_shoulder: Vector2 = Vector2(180.0, 270.0):
	set(value):
		police_shoulder = value
		_rebuild()
@export var villain_shoulder: Vector2 = Vector2(470.0, 310.0):
	set(value):
		villain_shoulder = value
		_rebuild()
## 한 번 내려치는 데 걸리는 시간(초). 짧을수록 매섭다
@export var swing_cycle: float = 0.78
## **몇 번 내려칠지.** 1이면 **팡! 한 번 치고 그 자세로 멎는다**(2026-10-14 사용자).
## 0이면 장면이 끝날 때까지 끝없이 되풀이한다
@export var strike_count: int = 1
## 뒤로 젖히는 각도와 내려쳤을 때 각도(도). 경찰은 이 부호대로, 할아버지는 반대로 돈다
@export var wind_up_deg: float = -19.0
@export var strike_deg: float = 15.0
## 한 바퀴 중 **젖히기가 끝나는 지점**과 **내려치기가 끝나는 지점**(0~1).
## 젖히기는 느리게, 내려치기는 순식간이어야 "쾅" 하고 꽂힌다
@export_range(0.1, 0.9, 0.01) var wind_up_at: float = 0.62
@export_range(0.1, 0.95, 0.01) var strike_at: float = 0.72
## 부딪힌 순간 몸이 뒤로 밀리는 거리(px)와 되돌아오는 빠르기
@export var hit_recoil: float = 15.0
## 부딪힌 순간 화면이 흔들리는 폭(px)과 가라앉는 시간(초)
@export var hit_shake: float = 24.0
@export var hit_shake_time: float = 0.3

@export_group("속도선")
## 속도선이 깜빡이는 빠르기와 가장 옅어질 때 진하기
@export var line_speed: float = 9.0
@export_range(0.0, 1.0, 0.05) var line_min_alpha: float = 0.45
## 깜빡이며 커지는 정도
@export var line_pulse: float = 0.03

var _layers: Dictionary = {}
var _time: float = 0.0
var _art: Vector2 = Vector2.ZERO
var _home: Vector2 = Vector2.ZERO
## 배경만 쓰는 크기·자리 — 인물보다 크게 잡아 화면을 덮는다
var _bg_art: Vector2 = Vector2.ZERO
var _bg_home: Vector2 = Vector2.ZERO

func _ready() -> void:
	_rebuild()
	set_process(true)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_layers.clear()
	if background_texture == null:
		return
	var view: Vector2 = _screen()
	var raw: Vector2 = Vector2(background_texture.get_size())
	# ⚠️ **인물과 배경을 다르게 맞춘다.** 그림이 거의 정사각(683x690)이라 16:9를 꽉 채우면
	# 위아래가 잘려 **상반신만 보인다**(2026-10-14 실측). 그래서
	#  - 인물은 **세로에 맞춰**(contain) 전신이 다 들어오게 하고
	#  - 배경만 **화면을 덮게**(cover) 키워 좌우 빈 곳을 메운다
	_art = raw * (minf(view.x / raw.x, view.y / raw.y) * overscan)
	_home = (view - _art) * 0.5 + art_offset
	_bg_art = raw * (maxf(view.x / raw.x, view.y / raw.y) * overscan)
	_bg_home = (view - _bg_art) * 0.5 + art_offset
	# **뒤에서부터 차례로.** 그림 파일 번호가 곧 포토샵 레이어 순서인데 **0000이 맨 위**다 —
	# 번호가 클수록 뒤로 간다(0007 배경이 맨 뒤, 0000 머리가 맨 앞).
	# 그래서 **팔은 몸보다 뒤**에 깔린다 — 뒤쪽 어깨가 몸 위로 떠오르면 안 된다(2026-10-14 사용자)
	_add("bg", background_texture)             # 0007
	_add("police_arm", police_arm_texture)     # 0006
	_add("police_body", police_body_texture)   # 0005
	_add("lines", speedline_texture)           # 0004
	_add("arm", villain_arm_texture)           # 0003
	_add("legs", villain_legs_texture)         # 0002
	_add("vest", villain_vest_texture)         # 0001
	_add("head", villain_head_texture)         # 0000

func _add(key: String, tex: Texture2D) -> void:
	if tex == null:
		return
	var node := TextureRect.new()
	node.name = key
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = _bg_art if key == "bg" else _art
	node.position = _bg_home if key == "bg" else _home
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 팔은 **어깨를 축으로** 돈다 — 그림 픽셀로 잡아 둔 어깨 자리를 지금 크기에 맞춰 옮긴다
	var shoulder: Vector2 = Vector2.ZERO
	if key == "police_arm":
		shoulder = police_shoulder
	elif key == "arm":
		shoulder = villain_shoulder
	if shoulder != Vector2.ZERO:
		node.pivot_offset = shoulder / Vector2(tex.get_size()) * _art
	add_child(node)
	_layers[key] = node

## ⚠️ 트리에 붙기 전에도 @export setter가 부른다 — 그때는 뷰포트가 없다
func _screen() -> Vector2:
	if not is_inside_tree():
		return Vector2(1280, 720)
	var rect: Rect2 = get_viewport_rect()
	return rect.size if rect.size.x > 1.0 else Vector2(1280, 720)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _layers.is_empty():
		return
	_time += delta
	# 배경이 아주 천천히 다가온다 — 멈춰 있는 그림에 숨을 넣는 정도
	var grow: float = 0.0
	if zoom_time > 0.0 and zoom_in > 0.0:
		grow = zoom_in * clampf(_time / zoom_time, 0.0, 1.0)

	# 한 바퀴 안에서의 진행도 — 젖혔다가 순식간에 내려치고 제자리로
	var cycle: float = maxf(swing_cycle, 0.05)
	# 정해진 횟수를 다 치면 **마지막 자세 그대로 멎는다** — 되풀이하면 "한 방"의 맛이 죽는다
	var spent: float = _time
	if strike_count > 0:
		spent = minf(_time, cycle * strike_count - 0.001)
	var u: float = fposmod(spent, cycle) / cycle
	var angle: float = 0.0
	var hit: float = 0.0            # 0=닿기 전, 1=막 닿은 순간
	if u < wind_up_at:
		# 뒤로 젖힌다 — 천천히 힘을 모은다
		angle = lerpf(0.0, wind_up_deg, _ease_out(u / wind_up_at))
	elif u < strike_at:
		# 내려친다 — 짧고 빠르게
		angle = lerpf(wind_up_deg, strike_deg, _ease_in((u - wind_up_at) / maxf(strike_at - wind_up_at, 0.01)))
	else:
		# 부딪힌 채로 버티다 제자리로
		var back: float = (u - strike_at) / maxf(1.0 - strike_at, 0.01)
		angle = lerpf(strike_deg, 0.0, _ease_out(back))
		hit = clampf(1.0 - (spent - cycle * floor(spent / cycle) - strike_at * cycle) / maxf(hit_shake_time, 0.01), 0.0, 1.0)

	# 부딪힌 순간에만 화면이 울리고 몸이 뒤로 밀린다
	var shake: Vector2 = Vector2.ZERO
	if hit > 0.0:
		var power: float = hit_shake * hit
		shake = Vector2(randf_range(-power, power), randf_range(-power, power) * 0.6)
	var recoil: float = hit_recoil * hit

	_put("bg", shake * 0.35, grow)
	_put("police_body", shake + Vector2(-recoil, 0.0), grow)
	_put("legs", shake + Vector2(recoil, 0.0), grow)
	_put("vest", shake + Vector2(recoil, 0.0), grow)
	_put("head", shake + Vector2(recoil, 0.0), grow)
	# 팔은 어깨를 축으로 돈다 — 두 사람이 서로를 향해 치므로 부호가 반대다
	_swing("police_arm", shake + Vector2(-recoil, 0.0), grow, angle)
	_swing("arm", shake + Vector2(recoil, 0.0), grow, -angle)

	var lines: TextureRect = _layers.get("lines")
	if lines != null and is_instance_valid(lines):
		# 부딪힐 때 확 밝아졌다가 사그라든다
		var wave: float = maxf((sin(_time * line_speed) + 1.0) * 0.5, hit)
		lines.modulate.a = lerpf(line_min_alpha, 1.0, wave)
		_put("lines", shake, grow + line_pulse * wave)

## 천천히 시작해 빠르게 끝난다(힘을 모으는 느낌)
func _ease_in(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * x

## 빠르게 시작해 천천히 멎는다
func _ease_out(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## 레이어 하나를 어깨 축으로 돌린다
func _swing(key: String, offset: Vector2, grow: float, degrees: float) -> void:
	var node: TextureRect = _layers.get(key)
	if node == null or not is_instance_valid(node):
		return
	_put(key, offset, grow)
	node.rotation_degrees = degrees

## 레이어 하나를 제자리에서 비켜 놓는다. `grow`만큼 가운데를 기준으로 키운다
func _put(key: String, offset: Vector2, grow: float) -> void:
	var node: TextureRect = _layers.get(key)
	if node == null or not is_instance_valid(node):
		return
	var base: Vector2 = _bg_art if key == "bg" else _art
	var home: Vector2 = _bg_home if key == "bg" else _home
	var size: Vector2 = base * (1.0 + grow)
	node.size = size
	node.position = home - (size - base) * 0.5 + offset
