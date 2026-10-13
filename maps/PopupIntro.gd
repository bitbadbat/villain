extends Node

## 대전 시작 팝업북 연출(2026-10-13 사용자 요청, 레퍼런스 = 단간론파) — **카메라는 정면에 가만히**, 맵 조각이
## 누운 종이에서 **하나씩 빠르게 "뚝" 하고 일어선다.**
## 배경(한 번에) → 소품(왼쪽부터 하나씩) → 앞쪽 장식(하나씩) → UI → 캐릭터(하나씩). 끝나면 원래 카운트다운.
##
## - 조각마다 **자기 밑변**을 축으로 선다 — 맵 바닥 하나를 축으로 하면 위에 떠 있는 물건이 바닥에서 휩쓸려 올라와
##   카메라가 같이 움직이는 것처럼 보였다(2026-10-13 사용자 지적으로 바꿈). 화면 전체 원근 휨도 같은 이유로 뺐다
## - 그림만 세운다. **물리 판정(StaticBody·Area·충돌 모양)은 절대 안 건드린다** — 캐릭터가 바닥을 뚫고 떨어지면 안 된다.
##   바디·영역 노드는 그 아래 그림 자식만, 판정이 섞인 묶음은 안으로 내려가 그림만 골라 세운다
## - 그림을 매 프레임 옮기는 스크립트(`ParallaxFollow` 등)와 싸우지 않게, 그쪽이 자리를 바꾸면 그 자리를 새 기준으로 삼는다
## - 쓰는 곳: `Stage._ready` — `prepare()`(첫 프레임 전에 납작하게) → 캐릭터·HUD가 생긴 뒤 `prepare_late()` → `play()`(await)

signal finished

## 층 차례 — 이름으로 가른다(맵마다 노드 이름 규칙이 비슷해서). 못 가른 건 소품
enum Layer { BACK, PROPS, FRONT, UI, CHARACTERS }

## 한 조각이 서는 데 걸리는 시간(초, 사용자 결정 0.2) — 끝에 살짝 넘었다가 "탁" 멈춘다
const POP_TIME := 0.2
## 층 안에서 조각끼리의 간격 — 조각이 많으면 이 범위 안에서 줄여 층 하나가 `LAYER_SPAN`을 안 넘게 한다
const GAP_MIN := 0.04
const GAP_MAX := 0.12
## 층마다 하나씩 서는 데 쓸 수 있는 최대 시간(배경은 한 번에라 0)
const LAYER_SPAN := [0.0, 0.8, 0.45, 0.0, 0.15]
## 앞 층이 다 서고 다음 층이 시작되기까지 쉬는 시간
const LAYER_PAUSE := 0.08
## 누운 상태의 세로 배율 — 0이면 변환이 깨진다
const FLAT := 0.002
## 누운 배경 위가 비어 Godot 기본 회색이 보이지 않게 깔 바탕색
const BACKDROP_COLOR := Color(0.07, 0.07, 0.09)

var _stage: Node = null
## 층마다 [{node, kind, start, hinge, ...원래 값}] — start는 play()에서 정한다
var _targets: Array = [[], [], [], [], []]
var _fighters: Array = []
var _fighter_start: Array = []
var _time: float = -1.0
var _end_time: float = 0.0
var _backdrop: ColorRect = null

func _init() -> void:
	name = "PopupIntro"
	# 그림을 옮기는 다른 스크립트(시차 등)보다 **나중에** 돌아야 그쪽이 고친 자리 위에 덮어쓴다
	process_priority = 1000

## 맵 그림을 전부 눕힌다 — 첫 프레임이 그려지기 전에 부를 것
func prepare(stage: Node) -> void:
	_stage = stage
	for child in stage.get_children():
		if child == self or child is CanvasLayer:
			continue
		var layer: int = _layer_of(child)
		if layer < 0:
			continue
		for t in _visual_targets(child, layer != Layer.BACK):
			_add_target(t, layer)
	_add_backdrop()
	_apply_all(-1.0)
	set_process(false)

## 캐릭터·HUD는 나중에 생긴다 — 생긴 뒤에 부른다
func prepare_late() -> void:
	var screen_bottom: float = get_viewport().get_visible_rect().size.y
	for child in _stage.get_children():
		if child is CanvasLayer and child.visible:
			_targets[Layer.UI].append({"node": child, "kind": "layer", "scale": child.scale, "offset": child.offset, "hinge": screen_bottom, "x": 0.0, "start": 0.0})
	var list: Array = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is CanvasItem and _stage.is_ancestor_of(f):
			list.append(f)
	list.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for f in list:
		_fighters.append(f)
		f.visible = false
	_apply_all(-1.0)

## 연출을 돌린다 — 끝나면 모든 그림을 원래대로 돌려놓고 finished
func play() -> void:
	_schedule()
	_time = 0.0
	set_process(true)
	await finished

## 조각마다 서는 시각을 정한다 — 층 순서대로, 층 안에서는 왼쪽부터
func _schedule() -> void:
	var t: float = 0.0
	for layer in [Layer.BACK, Layer.PROPS, Layer.FRONT, Layer.UI]:
		var items: Array = _targets[layer]
		if items.is_empty():
			continue
		items.sort_custom(func(a, b): return a["x"] < b["x"])
		var gap: float = 0.0
		if items.size() > 1 and LAYER_SPAN[layer] > 0.0:
			gap = clampf(LAYER_SPAN[layer] / float(items.size() - 1), GAP_MIN, GAP_MAX)
		for i in items.size():
			items[i]["start"] = t + gap * i
		t += gap * (items.size() - 1) + POP_TIME + LAYER_PAUSE
	var fgap: float = LAYER_SPAN[Layer.CHARACTERS]
	_fighter_start.clear()
	for i in _fighters.size():
		_fighter_start.append(t + fgap * i)
	_end_time = t + fgap * maxf(_fighters.size() - 1, 0) + POP_TIME + 0.15

func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += minf(delta, 0.05)
	_apply_all(_time)
	# 캐릭터는 자기 차례에 나타나며 위로 쭉 늘어났다 돌아온다(리그의 찌그러뜨리기 장치)
	for i in _fighters.size():
		var f = _fighters[i]
		if f == null or not is_instance_valid(f) or f.visible or _time < _fighter_start[i]:
			continue
		f.visible = true
		var visual: Node = f.get_node_or_null("Visual")
		if visual and visual.has_method("play_squash"):
			visual.play_squash(Vector2(1.15, 0.05))
	if _time >= _end_time:
		_finish()

func _finish() -> void:
	set_process(false)
	_time = -1.0
	_restore_all()
	finished.emit()
	queue_free()

## 연출 도중 씬이 바뀌어도 그림이 누운 채 남지 않게
func _exit_tree() -> void:
	if _time >= 0.0:
		_restore_all()

func _restore_all() -> void:
	_apply_all(INF)
	for f in _fighters:
		if is_instance_valid(f):
			f.visible = true
	if is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = null

func _add_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "PopupIntroBackdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.position = Vector2(-20000.0, -20000.0)
	_backdrop.size = Vector2(40000.0, 40000.0)
	_backdrop.z_as_relative = false
	_backdrop.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	_stage.add_child(_backdrop)

# ── 층·조각 가르기 ─────────────────────────────────────────────────────────

func _layer_of(node: Node) -> int:
	if node is CanvasModulate or node is Camera2D or node is Marker2D or node is Light2D:
		return -1
	if not (node is CanvasItem) and node.get_child_count() == 0:
		return -1
	var n: String = node.name
	if n == "ScreenGrade" or n.begins_with("PlayerSpawn") or n.begins_with("AISafeSpot"):
		return -1
	if n.contains("Foreground") or n.begins_with("DecoCeiling") or n.begins_with("Pole"):
		return Layer.FRONT
	for p in ["Deco", "Building", "Ground", "Track", "Floor", "Wall", "LeftWall", "RightWall", "Door"]:
		if n.begins_with(p):
			return Layer.BACK
	return Layer.PROPS

## 이 노드에서 세울 조각들 — 판정(바디·영역·충돌 모양)은 빼고 그림만.
## split이 켜져 있으면 그림 없는 묶음(Node2D 그 자체)은 자식 하나하나를 따로 세운다(기둥 여러 개 → 하나씩)
func _visual_targets(node: Node, split: bool) -> Array:
	var out: Array = []
	if node is CollisionShape2D or node is CollisionPolygon2D:
		return out
	if node is CollisionObject2D:
		for c in node.get_children():
			out.append_array(_visual_targets(c, split))
		return out
	if node is CanvasItem and not _has_physics_inside(node):
		if split and _is_plain_group(node):
			for c in node.get_children():
				out.append_array(_visual_targets(c, false))
			if not out.is_empty():
				return out
		out.append(node)
		return out
	for c in node.get_children():
		out.append_array(_visual_targets(c, split))
	return out

## 자기 그림 없이 자식만 묶는 Node2D인지(스크립트가 있으면 직접 그릴 수 있어 묶음으로 안 본다)
func _is_plain_group(node: Node) -> bool:
	if node.get_class() != "Node2D" or node.get_script() != null:
		return false
	var count: int = 0
	for c in node.get_children():
		if c is CanvasItem:
			count += 1
	return count >= 2

func _has_physics_inside(node: Node) -> bool:
	for c in node.get_children():
		if c is CollisionObject2D or c is CollisionShape2D or c is CollisionPolygon2D or _has_physics_inside(c):
			return true
	return false

func _add_target(node: CanvasItem, layer: int) -> void:
	var box: Rect2 = _visual_box(node)
	var hinge: float = box.end.y if box.size != Vector2.ZERO else (node.global_position.y if node is Node2D else 0.0)
	var x: float = box.get_center().x if box.size != Vector2.ZERO else 0.0
	if node is Node2D:
		_targets[layer].append({"node": node, "kind": "2d", "scale": node.scale, "base": node.position, "written": node.position, "hinge": hinge, "x": x, "start": 0.0})
	elif node is Control:
		var local_hinge: Vector2 = node.get_global_transform().affine_inverse() * Vector2(node.global_position.x, hinge)
		_targets[layer].append({"node": node, "kind": "control", "scale": node.scale, "pivot": node.pivot_offset, "local_hinge": local_hinge, "x": x, "start": 0.0})

## 그림이 실제로 차지하는 영역(월드 좌표) — 밑변이 서는 축이 되고, 가운데 x가 순서를 정한다
func _visual_box(node: Node) -> Rect2:
	var box := Rect2()
	var has: bool = false
	var own := Rect2()
	if node is Sprite2D and node.texture:
		own = node.get_global_transform() * node.get_rect()
		has = true
	elif node is Control:
		own = node.get_global_rect()
		has = true
	elif node is Polygon2D and node.polygon.size() > 0:
		var xf: Transform2D = node.get_global_transform()
		own = Rect2(xf * (node.polygon[0] + node.offset), Vector2.ZERO)
		for p in node.polygon:
			own = own.expand(xf * (p + node.offset))
		has = true
	if has:
		box = own
	for c in node.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D or not (c is CanvasItem) or not c.visible:
			continue
		var cb: Rect2 = _visual_box(c)
		if cb.size == Vector2.ZERO:
			continue
		box = cb if not has else box.merge(cb)
		has = true
	return box

# ── 세우기 ───────────────────────────────────────────────────────────────

## 조각 하나의 세움 정도(0 = 누움, 1 = 섬) — 0.2초 동안 빠르게, 끝에 살짝 넘었다가 돌아온다(ease-out-back)
func _rise(start: float, t: float) -> float:
	if t == INF:
		return 1.0
	var p: float = clampf((t - start) / POP_TIME, 0.0, 1.0)
	if p >= 1.0:
		return 1.0
	var c1: float = 1.7
	var q: float = p - 1.0
	return 1.0 + (c1 + 1.0) * q * q * q + c1 * q * q

func _apply_all(t: float) -> void:
	for layer in _targets.size():
		for e in _targets[layer]:
			_apply(e, maxf(_rise(e["start"], t) if t >= 0.0 else 0.0, FLAT))

func _apply(e: Dictionary, s: float) -> void:
	var node = e["node"]
	if not is_instance_valid(node):
		return
	match e["kind"]:
		"2d":
			# 다른 스크립트가 자리를 바꿨으면(시차) 그 자리가 새 기준
			if not node.position.is_equal_approx(e["written"]):
				e["base"] = node.position
			var base: Vector2 = e["base"]
			var parent: Node = node.get_parent()
			var hy: float = e["hinge"]
			if parent is CanvasItem:
				hy = ((parent as CanvasItem).get_global_transform().affine_inverse() * Vector2(0.0, e["hinge"])).y
			var pos := Vector2(base.x, hy + (base.y - hy) * s)
			node.position = pos
			node.scale = Vector2(e["scale"].x, e["scale"].y * s)
			e["written"] = pos
		"control":
			node.pivot_offset = e["local_hinge"] if s < 1.0 else e["pivot"]
			node.scale = Vector2(e["scale"].x, e["scale"].y * s)
		"layer":
			node.scale = Vector2(e["scale"].x, e["scale"].y * s)
			node.offset = Vector2(e["offset"].x, e["offset"].y + e["hinge"] * (1.0 - s))
