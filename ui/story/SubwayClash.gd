@tool
extends Node2D

## **지하철 격돌 컷신**(2026-10-13 사용자: "지하철 아저씨랑 경찰이랑 쾅 하고 부딪히는 연출").
##
## 그림 넉 장을 겹쳐 쓴다 — 뒤에서부터 **터널 → 창밖 → 지하철 내부 → 두 사람**.
## 내부 그림은 창문 자리가 뚫려 있어서(알파 0) 그 구멍으로 창밖이 비친다.
## 그래서 **창밖만 옆으로 흘리면 달리는 열차 안에 있는 것처럼 보인다** — 창틀은 내부 그림에 있어 안 움직인다.
##
## 두 사람은 화면 밖에서 달려들어 **가운데에서 부딪히고**, 그 순간 화면이 흔들리고 하얗게 번쩍인다.
## 부딪힌 뒤에는 서로 밀어내듯 잘게 떤다.

## 뒤에서부터 겹칠 그림 넉 장
@export var tunnel_color: Color = Color(0.05, 0.06, 0.09):
	set(value):
		tunnel_color = value
		_rebuild()
@export var window_texture: Texture2D = null:
	set(value):
		window_texture = value
		_rebuild()
@export var interior_texture: Texture2D = null:
	set(value):
		interior_texture = value
		_rebuild()
@export var police_texture: Texture2D = null:
	set(value):
		police_texture = value
		_rebuild()
@export var villain_texture: Texture2D = null:
	set(value):
		villain_texture = value
		_rebuild()

@export_group("창밖 흐름")
## 창밖이 한 쪽으로 흐르는 빠르기(px/초). 음수면 반대쪽
@export var window_speed: float = -520.0
## 창밖 그림을 몇 장 이어 붙일지 — 한 장이 끝나기 전에 다음 장이 들어와야 끊기지 않는다
@export var window_copies: int = 3

@export_group("달려들기")
## 두 사람이 화면 밖 어디서 출발하는지(화면 폭 대비). 1이면 화면 하나만큼 바깥.
## **멀리서 아주 빠르게 날아와 꽂히는 맛**을 내려고 1 너머까지 뺐다(2026-10-14 사용자)
@export var rush_from: float = 1.15
## 달려드는 데 걸리는 시간(초)
@export var rush_time: float = 0.17
## 부딪히기 전 잠깐 멈춰 서는 시간(초) — 바로 달려들면 눈이 못 따라간다
@export var rush_delay: float = 0.3

@export_group("충돌")
## 그림을 화면보다 이만큼 크게 그린다 — **흔들릴 때 가장자리가 드러나지 않게** 하는 여유분
@export_range(1.0, 1.3, 0.01) var overscan: float = 1.08
## 부딪힌 자리가 흔들리는 시간(초)과 폭(px)
@export var shake_time: float = 0.9
@export var shake_power: float = 26.0
## 하얗게 번쩍이는 시간(초)과 가장 밝을 때 진하기.
## 1에 가까우면 그림이 통째로 날아가서 **정작 부딪힌 그림이 안 보인다**(2026-10-13 실측)
@export var flash_time: float = 0.2
@export_range(0.0, 1.0, 0.05) var flash_power: float = 0.55
## 부딪힌 뒤 서로 밀어내며 떠는 폭(px)과 빠르기
@export var push_amount: float = 7.0
@export var push_speed: float = 26.0
## 부딪힐 때 사방으로 뻗는 충격선 개수(0이면 안 그린다)
@export var burst_lines: int = 26
@export var burst_color: Color = Color(1, 1, 1, 0.9)

@export_group("에디터")
## 에디터에서 부딪힌 순간을 미리 본다
@export var preview_clash: bool = false:
	set(value):
		preview_clash = value
		_rebuild()

var _tunnel: ColorRect = null
var _windows: Node2D = null
var _interior: TextureRect = null
var _police: TextureRect = null
var _villain: TextureRect = null
var _flash: ColorRect = null
var _burst: Node2D = null
var _time: float = 0.0
var _clash_at: float = 0.0
var _shake_left: float = 0.0
## 그림을 화면보다 크게 그려서 생긴 가로 여유분(음수) — 조각마다 이만큼 왼쪽에서 시작한다
var _side: float = 0.0

func _ready() -> void:
	_rebuild()
	_clash_at = rush_delay + rush_time
	set_process(true)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_tunnel = null
	if interior_texture == null:
		return
	var view: Vector2 = _screen()
	var scale_to_fit: float = view.x * overscan / float(interior_texture.get_width())
	var art: Vector2 = Vector2(interior_texture.get_size()) * scale_to_fit
	var top: float = (view.y - art.y) * 0.5
	_side = (view.x - art.x) * 0.5

	_tunnel = ColorRect.new()
	_tunnel.color = tunnel_color
	_tunnel.size = view * overscan
	_tunnel.position = (view - _tunnel.size) * 0.5
	_tunnel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tunnel)

	# 창밖은 같은 그림을 옆으로 여러 장 이어 붙여 돌려 쓴다
	_windows = Node2D.new()
	add_child(_windows)
	if window_texture != null:
		for i in maxi(window_copies, 1):
			var copy := TextureRect.new()
			copy.texture = window_texture
			copy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			copy.stretch_mode = TextureRect.STRETCH_SCALE
			copy.size = art
			copy.position = Vector2(_side + art.x * i, top)
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_windows.add_child(copy)

	_interior = _layer(interior_texture, art, top)
	_police = _layer(police_texture, art, top)
	_villain = _layer(villain_texture, art, top)

	_burst = Node2D.new()
	_burst.z_index = 5
	add_child(_burst)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = view * overscan
	_flash.position = (view - _flash.size) * 0.5
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 6
	add_child(_flash)

	if Engine.is_editor_hint():
		_place_fighters(1.0 if preview_clash else 0.0)

func _layer(tex: Texture2D, art: Vector2, top: float) -> TextureRect:
	if tex == null:
		return null
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = art
	node.position = Vector2(_side, top)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

## ⚠️ 트리에 붙기 전에도 @export setter가 부를 수 있다 — 그때는 뷰포트가 없다
func _screen() -> Vector2:
	if not is_inside_tree():
		return Vector2(1280, 720)
	var rect: Rect2 = get_viewport_rect()
	return rect.size if rect.size.x > 1.0 else Vector2(1280, 720)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_scroll_windows(delta)
	var u: float = 0.0
	if _time > rush_delay:
		u = clampf((_time - rush_delay) / maxf(rush_time, 0.01), 0.0, 1.0)
	_place_fighters(u)
	if _time >= _clash_at:
		_shake(delta)

## 창밖을 옆으로 흘린다 — 한 장이 화면 왼쪽으로 다 빠지면 맨 뒤로 보낸다
func _scroll_windows(delta: float) -> void:
	if _windows == null or _windows.get_child_count() == 0:
		return
	var span: float = (_windows.get_child(0) as TextureRect).size.x
	for child in _windows.get_children():
		var node := child as TextureRect
		node.position.x += window_speed * delta
		if node.position.x <= -span:
			node.position.x += span * _windows.get_child_count()
		elif node.position.x >= span * (_windows.get_child_count() - 1):
			node.position.x -= span * _windows.get_child_count()

## u가 0이면 화면 밖, 1이면 부딪힌 자리
func _place_fighters(u: float) -> void:
	# 5제곱으로 떨어뜨린다 — 거의 끝까지 멀리 있다가 **마지막 순간에 확** 꽂힌다
	var eased: float = 1.0 - pow(1.0 - u, 5.0)
	var away: float = _screen().x * rush_from * (1.0 - eased)
	# 부딪힌 뒤에는 서로 밀어내듯 잘게 떤다
	var push: float = 0.0
	if u >= 1.0 and not Engine.is_editor_hint():
		push = sin((_time - _clash_at) * push_speed) * push_amount
	if _police:
		_police.position.x = _side - away - push
	if _villain:
		_villain.position.x = _side + away + push

## 부딪힌 순간 화면을 흔들고 하얗게 번쩍인다
func _shake(delta: float) -> void:
	var since: float = _time - _clash_at
	if since <= delta and _shake_left <= 0.0:
		_shake_left = shake_time
		_spawn_burst()
	if _flash:
		_flash.color.a = clampf(1.0 - since / maxf(flash_time, 0.01), 0.0, 1.0) * flash_power
	if _shake_left > 0.0:
		_shake_left -= delta
		var power: float = shake_power * clampf(_shake_left / maxf(shake_time, 0.01), 0.0, 1.0)
		position = Vector2(randf_range(-power, power), randf_range(-power, power) * 0.6)
	else:
		position = Vector2.ZERO

## 부딪힌 자리에서 사방으로 뻗는 흰 선
func _spawn_burst() -> void:
	if _burst == null or burst_lines <= 0:
		return
	var center: Vector2 = _screen() * 0.5
	for i in burst_lines:
		var line := Line2D.new()
		var angle: float = TAU * i / burst_lines + randf_range(-0.06, 0.06)
		var near: float = randf_range(90.0, 150.0)
		var far: float = near + randf_range(120.0, 320.0)
		line.add_point(center + Vector2.RIGHT.rotated(angle) * near)
		line.add_point(center + Vector2.RIGHT.rotated(angle) * far)
		line.width = randf_range(3.0, 9.0)
		line.default_color = burst_color
		_burst.add_child(line)
		var tw: Tween = create_tween()
		tw.tween_property(line, "modulate:a", 0.0, randf_range(0.25, 0.5))
		tw.tween_callback(line.queue_free)
