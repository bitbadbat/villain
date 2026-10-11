extends Node2D

## 연행 장면 구경꾼 다섯 — **게임에 안 나오는 동네 사람들**(회사원·아줌마·학생·할아버지·핸드폰으로 찍는 사람).
## 2026-10-11 사용자: "뒤에 군중 캐릭터들 따로 5명정도 만들어서 지켜보게 해주면 좋겠음 — 게임에 나오는 캐릭터들은 안 나오도록".
## 전에는 이 판에 안 나온 로스터 리그가 서 있었는데, 그래서 둘이 싸워도 화면에 세 번째 로스터가 나왔다 — 그걸 없앴다.
##
## - 전신 그림 한 장씩(투명 배경 PNG)을 장면의 `crowd_feet` 자리에 세우고 **ArrestScene과 같은 카메라**로 투영한다(멀수록 작다)
## - **부위 리그 씬**(`OnlookerRig.gd`, 2026-10-11)이 있는 자리는 그림 대신 리그를 세운다 — 눈동자가 행렬(`look_target`)을 따라가고
##   깜빡이고 입을 움직이며, "어? 나도?" 때 `react()`로 놀란다. 리그가 없는 사람은 지금처럼 통짜 그림
## - 크기는 **그림에서 칠해진 영역의 높이**로 맞춘다(캔버스 여백은 그림마다 달라서) — 그 깊이에서 캐릭터 키 x height
## - 리미티드 애니: 숨쉬기 + 가끔 폴짝 + 연행 쪽(왼쪽)으로 목을 빼듯 기울기 + 가끔 옆 사람을 휙 돌아봤다가(좌우 뒤집기) 돌아온다
## - 그림이 아직 없는 자리는 **얼굴 없는 구경꾼(MobCrowd) 한 명**으로 채운다 — 무리가 비어 보이지 않게
## - 먼 사람부터 붙여서 앞사람이 뒷사람을 가린다. 장면의 `Stage/Crowd` 노드라 행렬(경찰·두 사람)보다 늘 뒤다
## 매 프레임 장면이 카메라 값을 넣고 `refresh()`를 부른다(장면이 리그보다 늦게 돌아서 그 뒤에 자리를 맞춘다).
## class_name을 일부러 안 단다 — ArrestScene.tscn의 Crowd 노드에 붙어 있다

const MobScript = preload("res://ui/result/MobCrowd.gd")

## 옆 사람을 돌아보는(좌우 뒤집는) 사람의 몫 / 돌아보고 있는 시간(초)
const TURN_CHANCE := 0.4
const TURN_TIME := 0.42

# --- ArrestScene이 매 프레임 넣는 값 ---
var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 실제 시간(초)
var time: float = 0.0
## 얼굴 없는 사람(빈자리 채우기)의 밝기·공기색 — 장면이 setup 전에 넣고, 밤이면 공기색을 바꾼다
var mob_shade: float = 1.0
var mob_haze: Color = Color(0.85, 0.89, 0.95)
## 리그 구경꾼이 바라볼 곳(전역 좌표) — 장면이 매 프레임 행렬 가운데를 넣는다
var look_target: Vector2 = Vector2(640, 420)

## 사람마다 {node, body, sprite, mob, world, k_unit, anchor, flip, size, ...}
var _figures: Array = []

## 그림 경로 -> 칠해진 영역(그림 좌표)
static var _opaque_cache: Dictionary = {}

## 구경꾼을 새로 세운다. worlds = 자리마다 발 위치(월드 X, 0, Z), textures[i]가 비면 그 자리는 얼굴 없는 사람.
## flips[i] = 그 그림을 좌우로 뒤집어 세울지, sizes[i] = 그 사람 키 배율(비면 1). height = 캐릭터 키 대비 키.
## scenes[i]에 부위 리그 씬이 있으면 그림 대신 그 리그를 세운다
func setup(worlds: Array, textures: Array, flips: Array, sizes: Array, height: float, seed_value: int = 5, scenes: Array = []) -> void:
	for child in get_children():
		child.queue_free()
	_figures.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var entries: Array = []
	for i in worlds.size():
		var tex: Texture2D = textures[i] as Texture2D if i < textures.size() else null
		var size_mul: float = float(sizes[i]) if i < sizes.size() and float(sizes[i]) > 0.0 else 1.0
		entries.append({
			"world": worlds[i], "tex": tex,
			"scene": scenes[i] as PackedScene if i < scenes.size() else null,
			"flip": i < flips.size() and bool(flips[i]),
			"size": height * size_mul * rng.randf_range(0.97, 1.03),
			"phase": rng.randf() * TAU,
			"breath": rng.randf_range(2.2, 3.1),
			"hop_at": rng.randf_range(0.25, 2.6), "hop_every": rng.randf_range(2.6, 4.2),
			"crane_at": rng.randf_range(0.2, 2.2), "crane_deg": rng.randf_range(4.0, 7.0),
			"lean_deg": rng.randf_range(0.8, 2.2),
			"turn_at": rng.randf_range(0.7, 2.3) if rng.randf() < TURN_CHANCE else -1.0,
			"seed": seed_value * 31 + i,
		})
	# 먼(z가 큰) 사람부터 붙여야 앞사람이 뒷사람을 가린다
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["world"] as Vector3).z > (b["world"] as Vector3).z)
	for e in entries:
		if e["scene"] != null:
			_figures.append(_make_rig_figure(e))
		elif e["tex"] != null:
			_figures.append(_make_sprite_figure(e))
		else:
			_figures.append(_make_mob_figure(e))
	refresh()

func _make_sprite_figure(e: Dictionary) -> Dictionary:
	var tex: Texture2D = e["tex"]
	var node := FigureShadow.new()
	add_child(node)
	var body := Node2D.new()
	node.add_child(body)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var o: Rect2 = opaque_rect(tex)
	# 칠해진 영역의 **발 가운데**가 원점에 오게 — 몸(body)을 돌리고 줄이고 뒤집는 축이 곧 발밑이다
	sprite.position = -Vector2(o.position.x + o.size.x * 0.5, o.end.y)
	body.add_child(sprite)
	e["node"] = node
	e["body"] = body
	e["k_unit"] = float(e["size"]) / maxf(o.size.y, 1.0)
	e["half_w"] = o.size.x * 0.5
	return e

## 부위 리그 구경꾼 — 리그 원점(두 발 가운데 땅)이 곧 발밑이다. 키는 리그가 잰 쉬는 자세 네모로 맞춘다
func _make_rig_figure(e: Dictionary) -> Dictionary:
	var node := FigureShadow.new()
	add_child(node)
	var body := Node2D.new()
	node.add_child(body)
	var rig := (e["scene"] as PackedScene).instantiate() as Node2D
	body.add_child(rig)   # add_child가 _ready()를 바로 불러 쉬는 자세 네모를 잰다
	var b: Rect2 = rig.call("bounds")
	rig.position = Vector2(0.0, -b.end.y)
	e["node"] = node
	e["body"] = body
	e["rig"] = rig
	e["k_unit"] = float(e["size"]) / maxf(b.size.y, 1.0)
	# 그림자는 몸 폭만 — 지팡이·꼬치처럼 옆으로 삐져나온 소품까지 넣으면 너무 넓다
	e["half_w"] = b.size.x * 0.35
	return e

## "어? 나도?" — 리그 구경꾼이 다 같이 놀란다(통짜 그림은 그대로)
func react() -> void:
	for f in _figures:
		if f.has("rig"):
			(f["rig"] as Node).call("react")

func _make_mob_figure(e: Dictionary) -> Dictionary:
	var mob := Node2D.new()
	mob.set_script(MobScript)
	mob.set("shade", mob_shade)
	mob.set("haze", mob_haze)
	add_child(mob)
	mob.call("setup", [e["world"]], int(e["seed"]))
	e["node"] = mob
	e["mob"] = true
	return e

## 밤이면 얼굴 없는 사람이 하늘빛 안개에 녹지 않게 공기색을 바꾼다
func set_mob_haze(color: Color) -> void:
	mob_haze = color
	for f in _figures:
		if f.has("mob"):
			(f["node"] as Node2D).set("haze", color)

## 이번 프레임 자리·크기·몸짓을 맞춘다(장면이 카메라 값을 넣은 뒤 부른다)
func refresh() -> void:
	for f in _figures:
		var node: Node2D = f["node"]
		if f.has("mob"):
			node.set("vanish_x", vanish_x)
			node.set("horizon_y", horizon_y)
			node.set("camera_height", camera_height)
			node.set("focal", focal)
			node.set("dolly", dolly)
			node.set("time", time)
			continue
		_pose_sprite(f)
		if f.has("rig"):
			# 옆 사람을 휙 돌아보는 동안은 눈도 그쪽(돌아본 쪽 = 평소 보던 반대쪽)을 본다
			var target: Vector2 = look_target
			var turn_at: float = float(f["turn_at"])
			if turn_at >= 0.0 and time >= turn_at and time < turn_at + TURN_TIME:
				target = node.global_position + Vector2(-400.0 if bool(f["flip"]) else 400.0, -60.0)
			(f["rig"] as Node).call("tick", time, target)

func _pose_sprite(f: Dictionary) -> void:
	var world: Vector3 = f["world"]
	var z: float = maxf(world.z - dolly, 0.05)
	var unit: float = focal / z
	var node: FigureShadow = f["node"]
	node.position = Vector2(vanish_x + focal * world.x / z, horizon_y + focal * camera_height / z)
	var k: float = unit * float(f["k_unit"])
	# 숨쉬기 — 발을 축으로 세로만 아주 조금
	var breath: float = sin(time * TAU / float(f["breath"]) + float(f["phase"]))
	var sx: float = k * (1.0 - 0.006 * breath)
	var sy: float = k * (1.0 + 0.012 * breath)
	# 가끔 수군거리듯 두 번 폴짝(MobCrowd와 같은 박자 모양)
	var hop_t: float = time - float(f["hop_at"])
	var hop: float = 0.0
	if hop_t >= 0.0:
		hop_t = fposmod(hop_t, float(f["hop_every"]))
		if hop_t < 0.36:
			hop = absf(sin(hop_t / 0.18 * PI)) * 0.035
	# 연행 쪽(왼쪽)으로 기울기 — 평소 살짝 + 한 번 목을 빼듯 더(음수 회전 = 윗몸이 왼쪽)
	var crane: float = _bump(time - float(f["crane_at"]), 0.9) * float(f["crane_deg"])
	var body: Node2D = f["body"]
	body.rotation = -deg_to_rad(float(f["lean_deg"]) + crane)
	body.position = Vector2(0.0, -hop * unit * float(f["size"]))
	var facing: float = -1.0 if bool(f["flip"]) else 1.0
	var turn_at: float = float(f["turn_at"])
	if turn_at >= 0.0 and time >= turn_at and time < turn_at + TURN_TIME:
		facing = -facing   # 옆 사람을 휙 돌아봤다가 돌아온다
	body.scale = Vector2(sx * facing, sy)
	# 발밑 그림자 — 멀수록 납작하다(연행 인물의 그림자와 같은 식)
	var rx: float = float(f["half_w"]) * k * 0.8
	node.set_radius(Vector2(rx, rx * camera_height / z * 1.25))

## 0에서 1로 부드럽게 올라갔다 내려오는 한 번(len초 동안). 범위 밖은 0
static func _bump(s: float, length: float) -> float:
	if s <= 0.0 or s >= length:
		return 0.0
	return sin(s / length * PI)

## 그림에서 반쯤 이상 불투명한 영역(그림 좌표). 작게 줄여서 잰다 — 큰 전신 그림을 한 점씩 보면 첫 프레임이 끊긴다
static func opaque_rect(tex: Texture2D) -> Rect2:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var size: Vector2 = tex.get_size()
	var rect := Rect2(Vector2.ZERO, size)
	var img: Image = tex.get_image()
	if img != null and size.x > 0.0 and size.y > 0.0:
		if img.is_compressed():
			img.decompress()
		var shrink: float = minf(1.0, 160.0 / maxf(size.x, size.y))
		var w: int = maxi(int(round(size.x * shrink)), 1)
		var h: int = maxi(int(round(size.y * shrink)), 1)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var min_p := Vector2i(w, h)
		var max_p := Vector2i(-1, -1)
		for yy in h:
			for xx in w:
				if img.get_pixel(xx, yy).a >= 0.5:
					min_p = Vector2i(mini(min_p.x, xx), mini(min_p.y, yy))
					max_p = Vector2i(maxi(max_p.x, xx), maxi(max_p.y, yy))
		if max_p.x >= 0:
			var sx: float = size.x / w
			var sy: float = size.y / h
			rect = Rect2(min_p.x * sx, min_p.y * sy, (max_p.x - min_p.x + 1) * sx, (max_p.y - min_p.y + 1) * sy)
	_opaque_cache[key] = rect
	return rect

## 구경꾼 한 명의 뿌리 — 발밑 그림자를 그리고, 자식(몸)이 그 위에 그려진다
class FigureShadow extends Node2D:
	var radius: Vector2 = Vector2.ZERO
	var color: Color = Color(0.16, 0.11, 0.09, 0.27)

	## 반지름이 바뀌었을 때만 다시 그린다
	func set_radius(r: Vector2) -> void:
		if r.is_equal_approx(radius):
			return
		radius = r
		queue_redraw()

	func _draw() -> void:
		if radius.x < 0.5 or radius.y < 0.3:
			return
		var pts := PackedVector2Array()
		for i in 28:
			var t: float = TAU * i / 28.0
			pts.append(Vector2(cos(t) * radius.x, sin(t) * radius.y))
		draw_colored_polygon(pts, color)
