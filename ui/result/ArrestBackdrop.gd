extends Node2D

## 연행 장면(ArrestScene)의 뒤 배경 — 하늘·뭉게구름·지평선의 먼 건물과 나무·바닥(도로/연석/보도 타일)을 코드로 그린다.
## 바닥은 ArrestScene과 **같은 카메라**로 투영한다: 연석·타일 세로선은 소실점으로 모이고, 가로선은 앞으로 올수록 벌어진다.
## 밀고 들어가기(dolly) 중엔 가로선만 아래로 흘러서 "앞으로 다가간다"로 읽힌다(소실점으로 모이는 선은 원래 안 움직인다).
## 구름은 원작처럼 크고 둥근 뭉게구름 — 게임 그림체에 맞춰 흰 윗면 + 푸른 그늘 + 테두리로 납작하게 칠한다
##
## **밤**(맵 설정 ArrestBackdropConfig.night, 장면이 `set_night()`로 넣는다): 남색 하늘 + 반짝이는 별 + 달, 지평선엔 불 켜진 먼 빌딩 줄,
## 건물 뒤 먼 길(지평선 ~ 건물 땅선)은 어둡게 — 건물 그림 사이사이 투명한 틈 어디로 봐도 "밤"이 보이게.
## 구름은 어두운 밤구름이 되고, 앞길은 살짝만 밤빛으로 물든다(인물은 장면이 안 건드린다)
##
## ⚠️ 구름·먼 나무는 원 수백 개라 `draw_circle`로 그리면 원 하나가 그리기 한 번(draw call)이 되어
## 연행 장면이 30fps까지 떨어졌다(2026-10-08 실측, 배경만 끄면 79fps). 그래서 원은 **삼각형 묶음 하나**(`_fill_circles`)로 칠하고,
## 구름은 한 덩이씩 자식 노드에 한 번만 그려 자리만 옮기며, 먼 나무·건물은 보이는 것이 바뀔 때만 다시 그린다

const LineMesh = preload("res://ui/result/LineMesh.gd")

# --- ArrestScene이 매 프레임 넣는 값 ---
## 화면에 보이는 영역(이 노드 좌표). 넓은 화면이면 1280x720보다 넓다
var view_rect: Rect2 = Rect2(0, 0, 1280, 720)
var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 실제 시간(초) — 구름이 흐르는 데만 쓴다
var time: float = 0.0
## 경찰서 건물이 가리는 가로 범위(이 노드 좌표) — 그 안쪽엔 먼 나무·건물을 안 그린다(밤엔 틈으로 보이게 먼 빌딩은 그린다)
var building_span: Vector2 = Vector2(760, 1374)
## 건물이 땅에 닿는 화면 높이(밀고 들어가기 반영) — 밤엔 지평선 ~ 이 선(건물 뒤 먼 길)을 어둡게 칠한다
var facade_ground_y: float = 548.0
## 밤 하늘인지 / 달을 띄울지 — 장면이 `set_night()`로 넣는다
var night: bool = false
var night_moon: bool = true

@export_group("하늘")
@export var sky_top: Color = Color(0.15, 0.4, 0.84)
@export var sky_mid: Color = Color(0.31, 0.6, 0.93)
@export var sky_horizon: Color = Color(0.74, 0.88, 1.0)

@export_group("구름")
@export var cloud_light: Color = Color(1.0, 1.0, 1.0)
@export var cloud_shade: Color = Color(0.8, 0.88, 0.97)
@export var cloud_line: Color = Color(0.47, 0.64, 0.87)
@export var cloud_line_width: float = 3.0
## 구름이 흐르는 빠르기(px/초, 큰 구름 기준 — 작은 구름은 더 느리다)
@export var cloud_speed: float = 7.0

@export_group("먼 풍경")
@export var tree_light: Color = Color(0.47, 0.75, 0.37)
@export var tree_shade: Color = Color(0.31, 0.59, 0.3)
@export var tree_line: Color = Color(0.16, 0.29, 0.17)
@export var city_color: Color = Color(0.66, 0.76, 0.89)

@export_group("밤")
@export var night_sky_top: Color = Color(0.02, 0.03, 0.1)
@export var night_sky_mid: Color = Color(0.05, 0.08, 0.22)
## 지평선 쪽 — 도시 불빛이 번진 보랏빛
@export var night_sky_horizon: Color = Color(0.22, 0.17, 0.36)
## 건물 뒤 먼 길(지평선 → 건물 땅선) — 틈으로 보이는 골목 어둠
@export var night_far_top: Color = Color(0.12, 0.1, 0.21)
@export var night_far_bottom: Color = Color(0.06, 0.06, 0.12)
## 얼굴 없는 구경꾼이 멀수록 녹아드는 공기색(낮의 하늘빛 대신 — 장면이 읽어 간다)
@export var night_haze: Color = Color(0.2, 0.21, 0.34)
@export var night_cloud_light: Color = Color(0.3, 0.32, 0.5)
@export var night_cloud_shade: Color = Color(0.2, 0.22, 0.38)
@export var night_cloud_line: Color = Color(0.08, 0.09, 0.18)
## 먼 빌딩 실루엣 / 불 켜진 창 / 불 켜진 창의 몫
@export var night_city: Color = Color(0.08, 0.09, 0.19)
@export var night_window: Color = Color(1.0, 0.8, 0.45)
@export_range(0.0, 1.0, 0.01) var night_window_ratio: float = 0.32
## 먼 빌딩 키를 낮보다 이만큼 높게(밤엔 빌딩 줄이 틈으로 보여야 도시 밤으로 읽힌다)
@export var night_city_height: float = 1.6
@export var night_tree_light: Color = Color(0.12, 0.17, 0.22)
@export var night_tree_shade: Color = Color(0.08, 0.12, 0.17)
@export var night_tree_line: Color = Color(0.03, 0.04, 0.08)
@export var star_color: Color = Color(1.0, 0.96, 0.84)
@export var star_count: int = 230
## 달 — 자리(1280x720 기준 화면 px)·반지름·색. 건물 그림의 틈에 맞춰 옮길 것
@export var moon_center: Vector2 = Vector2(905, 78)
@export var moon_radius: float = 30.0
@export var moon_color: Color = Color(1.0, 0.95, 0.74)
@export var moon_line: Color = Color(0.45, 0.36, 0.2)
## 앞길(보도·도로)을 밤빛(night_ground_color)으로 얼마나 물들일지 — 0이면 낮 그대로. 인물은 안 건드린다
@export_range(0.0, 0.6, 0.01) var night_ground_tint: float = 0.16
@export var night_ground_color: Color = Color(0.24, 0.26, 0.44)

@export_group("바닥")
## 도로와 보도를 가르는 연석의 월드 X(캐릭터 키 = 1). 이보다 왼쪽이 도로
@export var curb_x: float = -0.95
@export var curb_width: float = 0.08
## 보도 타일 한 칸(월드)
@export var tile_size: float = 0.55
## 도로 가운데 점선의 월드 X
@export var lane_x: float = -2.7
@export var walk_near: Color = Color(0.89, 0.8, 0.64)
@export var walk_far: Color = Color(0.9, 0.87, 0.81)
@export var tile_line: Color = Color(0.68, 0.58, 0.43, 0.75)
@export var road_near: Color = Color(0.33, 0.35, 0.41)
@export var road_far: Color = Color(0.56, 0.6, 0.68)
@export var curb_color: Color = Color(0.95, 0.94, 0.9)
@export var edge_line: Color = Color(0.13, 0.13, 0.16)
@export var lane_color: Color = Color(0.97, 0.97, 0.94, 0.92)
## 아래쪽을 살짝 어둡게(앞이 무겁게) — 0이면 안 함
@export_range(0.0, 0.5, 0.01) var bottom_shade: float = 0.13

## 구름마다 {x, y, size, speed, puffs: [Vector3(x, y, 반지름)]} — 단위 공간(가로 약 4)에서 size배
var _clouds: Array = []
## 먼 나무 덩어리 [Vector3(x, 반지름, 밝은 쪽 비율)] / 먼 건물 [Rect2]
var _trees: Array = []
var _city: Array = []
## 별마다 [자리, 반지름, 위상, 빠르기] — 밤에만 그린다
var _stars: Array = []
## 구름 한 덩이씩 그려 둔 자식 노드(_clouds와 같은 순서)
var _cloud_nodes: Array[Node2D] = []
## 먼 나무·건물을 그려 둔 자식 노드와, 마지막으로 그린 때의 [지평선, 보이는 나무 번호, 보이는 건물 번호]
var _far: Node2D = null
var _far_key: Array = []
## 세로 줄눈 삼각형 묶음과 그것을 쌓은 때의 화면 값
var _column_mesh: LineMesh = null
var _column_key: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242   # 판마다 모양이 바뀌면 "다른 장소"처럼 보인다 — 늘 같은 하늘
	# 작은(먼) 구름부터 — 그리는 순서가 곧 앞뒤
	var layout: Array = [
		[1500.0, 300.0, 30.0, 0.55], [430.0, 330.0, 24.0, 0.5], [-140.0, 255.0, 34.0, 0.6],
		[640.0, 92.0, 40.0, 0.75], [1130.0, 148.0, 72.0, 1.0], [215.0, 172.0, 64.0, 0.95],
	]
	for entry in layout:
		_clouds.append({"x": entry[0], "y": entry[1], "size": entry[2], "speed": entry[3], "puffs": _make_cloud(rng)})
	var x: float = -900.0
	while x < 2300.0:
		var r: float = rng.randf_range(10.0, 19.0)
		if rng.randf() < 0.18:
			r = rng.randf_range(21.0, 27.0)   # 가끔 큰 나무가 솟아야 줄이 밋밋하지 않다
		_trees.append(Vector3(x, r, rng.randf_range(0.0, 1.0)))
		x += r * rng.randf_range(1.05, 1.5)
	x = -900.0
	while x < 2300.0:
		var w: float = rng.randf_range(40.0, 95.0)
		var h: float = rng.randf_range(26.0, 74.0)
		_city.append(Rect2(x, -h, w, h))
		x += w + rng.randf_range(-10.0, 30.0)
	# 별은 따로 굴린다 — 위 rng에 섞으면 낮 하늘의 구름·나무 모양이 바뀐다
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 777
	for i in star_count:
		var big: bool = star_rng.randf() < 0.12
		_stars.append([
			# 위로 -400까지 깐다 — 16:9보다 세로로 긴 화면(16:10·4:3)은 view_rect가 위로 늘어나 하늘 꼭대기에 별 없는 띠가 생겼다
			Vector2(star_rng.randf_range(-900.0, 2300.0), lerpf(-400.0, horizon_y - 70.0, pow(star_rng.randf(), 1.2))),
			star_rng.randf_range(2.0, 3.0) if big else star_rng.randf_range(0.9, 1.8),
			star_rng.randf() * TAU, star_rng.randf_range(1.5, 4.0),
		])
	# 자식은 부모 그림 위에 그려진다 — 하늘·바닥(부모) → 구름 → 먼 풍경. 구름은 지평선보다 한참 위라 먼 풍경과 안 겹친다
	for c in _clouds:
		var cloud := CloudDrawing.new()
		cloud.backdrop = self
		cloud.puffs = c["puffs"]
		cloud.size = c["size"]
		add_child(cloud)
		_cloud_nodes.append(cloud)
	var far := FarDrawing.new()
	far.backdrop = self
	add_child(far)
	_far = far
	# ArrestScene(process_priority 100)이 이번 프레임 값(시간·dolly·건물 폭)을 넣은 **뒤에** 자리를 맞춘다
	process_priority = 200

## 밤으로 바꾸거나 되돌린다 — 구름은 한 번 그려 두는 그림이라 다시 그리게 하고, 먼 풍경도 다시 그린다
func set_night(on: bool, moon: bool = true) -> void:
	if on == night and moon == night_moon:
		return
	night = on
	night_moon = moon
	for cloud in _cloud_nodes:
		cloud.queue_redraw()
	_far_key = []

## 뭉게구름 한 덩이 — 아래 줄 작은 공 + 위 줄 큰 공 + 꼭대기 하나
func _make_cloud(rng: RandomNumberGenerator) -> Array:
	var puffs: Array = []
	var bottom: int = rng.randi_range(4, 5)
	for i in bottom:
		var t: float = float(i) / float(bottom - 1)
		puffs.append(Vector3(lerpf(-1.65, 1.65, t), rng.randf_range(-0.05, 0.05), rng.randf_range(0.5, 0.66)))
	var top: int = rng.randi_range(2, 3)
	for i in top:
		var t: float = float(i) / float(maxi(top - 1, 1))
		puffs.append(Vector3(lerpf(-0.95, 0.95, t) + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.62, -0.5), rng.randf_range(0.72, 0.9)))
	puffs.append(Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-1.12, -0.98), rng.randf_range(0.62, 0.78)))
	return puffs

func _process(_delta: float) -> void:
	queue_redraw()
	_place_clouds()
	_refresh_far()

func _draw() -> void:
	var left: float = view_rect.position.x - 4.0
	var right: float = view_rect.end.x + 4.0
	var top: float = view_rect.position.y - 4.0
	var bottom: float = view_rect.end.y + 4.0
	_draw_sky(left, right, top)
	_draw_ground(left, right, bottom)

func _draw_sky(left: float, right: float, top: float) -> void:
	var mid_y: float = lerpf(top, horizon_y, 0.55)
	if night:
		_grad_quad(left, right, top, mid_y, night_sky_top, night_sky_mid)
		_grad_quad(left, right, mid_y, horizon_y + 2.0, night_sky_mid, night_sky_horizon)
		_draw_night_lights(left, right)
		return
	_grad_quad(left, right, top, mid_y, sky_top, sky_mid)
	_grad_quad(left, right, mid_y, horizon_y + 2.0, sky_mid, sky_horizon)

## 별(반짝임) + 달 — 삼각형 묶음 하나로 그린다(별 수십 개를 draw_circle로 그리면 그리기 횟수가 그만큼 는다)
func _draw_night_lights(left: float, right: float) -> void:
	var mesh := LineMesh.new()
	for star in _stars:
		var pos: Vector2 = star[0]
		if pos.x < left - 6.0 or pos.x > right + 6.0:
			continue
		var r: float = star[1]
		var twinkle: float = 0.6 + 0.4 * sin(time * float(star[3]) + float(star[2]))
		var col := Color(star_color, star_color.a * twinkle)
		mesh.add_disc(pos, r * (0.85 + 0.15 * twinkle), col, 8)
		if r > 1.9:
			# 큰 별은 십자로 반짝 — 가는 마름모 두 개
			var arm: float = r * (2.6 + 1.6 * twinkle)
			var thin: float = r * 0.32
			mesh.add_fill(PackedVector2Array([pos + Vector2(0, -arm), pos + Vector2(thin, 0), pos + Vector2(0, arm), pos + Vector2(-thin, 0)]), col)
			mesh.add_fill(PackedVector2Array([pos + Vector2(-arm, 0), pos + Vector2(0, -thin), pos + Vector2(arm, 0), pos + Vector2(0, thin)]), col)
	if night_moon and moon_radius > 0.0:
		_add_moon(mesh, moon_center, moon_radius)
	mesh.draw_on(self)

## 초승달(오른쪽 아래가 밝은 쪽) + 은은한 달무리. 바깥 호와 안쪽 호를 같은 높이끼리 띠로 이어 채운다(오목해도 안 삐져나온다)
func _add_moon(mesh: LineMesh, c: Vector2, r: float) -> void:
	for ring in [[2.7, 0.05], [1.9, 0.07], [1.35, 0.09]]:
		mesh.add_disc(c, r * float(ring[0]), Color(moon_color, float(ring[1])), 48)
	var lit_dir: float = deg_to_rad(28.0)   # 밝은 쪽이 바라보는 방향(오른쪽 살짝 아래)
	var tip: float = deg_to_rad(118.0)      # 두 뿔이 바깥 원에서 이루는 각
	var steps: int = 28
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var tip_x: float = cos(tip)
	for i in steps + 1:
		var a: float = lerpf(-tip, tip, float(i) / steps)
		var ox: float = cos(a)
		var oy: float = sin(a)
		var ix: float = tip_x + (ox - tip_x) * 0.42   # 안쪽 호 — 뿔에서 만나고 가운데가 덜 부푼다
		outer.append(c + Vector2(ox, oy).rotated(lit_dir) * r)
		inner.append(c + Vector2(ix, oy).rotated(lit_dir) * r)
	for i in steps:
		mesh.add_fill(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), moon_color)
	var outline := outer.duplicate()
	for i in range(steps, -1, -1):
		outline.append(inner[i])
	mesh.add_line(outline, PackedColorArray([moon_line]), maxf(r * 0.07, 1.4), true)

## 구름은 다시 그리지 않고 자리만 옮긴다(화면 밖으로 나가면 반대편에서 다시 들어온다)
func _place_clouds() -> void:
	var span_left: float = view_rect.position.x - 320.0
	var span: float = view_rect.size.x + 640.0
	for i in _cloud_nodes.size():
		var c: Dictionary = _clouds[i]
		var cx: float = span_left + fposmod(float(c["x"]) - span_left + time * cloud_speed * float(c["speed"]), span)
		_cloud_nodes[i].position = Vector2(cx, c["y"])

## 보이는 먼 나무·건물이 바뀌었을 때만(화면 폭·건물 폭이 달라졌을 때) 다시 그리게 한다
func _refresh_far() -> void:
	var left: float = view_rect.position.x - 4.0
	var right: float = view_rect.end.x + 4.0
	var key: Array = [horizon_y, _visible_trees(left, right), _visible_city(left, right), night]
	if key != _far_key:
		_far_key = key
		_far.queue_redraw()

func _visible_city(left: float, right: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _city.size():
		var rect: Rect2 = _city[i]
		if rect.end.x < left or rect.position.x > right:
			continue
		# 밤엔 건물 뒤에도 그린다 — 건물 그림 사이 틈으로 불 켜진 먼 빌딩이 보이게
		if not night and rect.position.x > building_span.x + 60.0 and rect.end.x < building_span.y - 60.0:
			continue
		out.append(i)
	return out

func _visible_trees(left: float, right: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _trees.size():
		var tree: Vector3 = _trees[i]
		if tree.x + tree.y < left or tree.x - tree.y > right:
			continue
		if tree.x > building_span.x + 70.0 and tree.x < building_span.y - 70.0:
			continue
		out.append(i)
	return out

## 구름 한 덩이(구름 가운데가 원점). 테두리 → 그늘 → 밝은 윗면 순으로 겹쳐 칠하면 덩어리 하나로 읽힌다
func _draw_cloud_on(canvas: CanvasItem, puffs: Array, size: float) -> void:
	var line_c: Color = night_cloud_line if night else cloud_line
	var shade_c: Color = night_cloud_shade if night else cloud_shade
	var light_c: Color = night_cloud_light if night else cloud_light
	var circles: Array = []
	for p in puffs:
		circles.append([Vector2(p.x, p.y) * size, p.z * size + cloud_line_width, line_c])
	for p in puffs:
		circles.append([Vector2(p.x, p.y) * size, p.z * size, shade_c])
	for p in puffs:
		var lift: float = 0.3 if p.y > -0.3 else 0.16
		circles.append([Vector2(p.x - p.z * 0.1, p.y - p.z * lift) * size, p.z * size * 0.78, light_c])
	_fill_circles(canvas, circles)

## 먼 건물 → 먼 나무(이 노드 좌표 그대로)
func _draw_far_on(canvas: CanvasItem) -> void:
	if _far_key.size() < 3:
		return
	if night:
		_draw_night_city(canvas, _far_key[2])
	else:
		for i in (_far_key[2] as PackedInt32Array):
			var rect: Rect2 = _city[i]
			canvas.draw_rect(Rect2(rect.position + Vector2(0.0, horizon_y), rect.size + Vector2(0.0, 2.0)), city_color)
	var t_line: Color = night_tree_line if night else tree_line
	var t_shade: Color = night_tree_shade if night else tree_shade
	var t_light: Color = night_tree_light if night else tree_light
	var visible: PackedInt32Array = _far_key[1]
	var circles: Array = []
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x, horizon_y - tree.y * 0.42), tree.y + 2.2, t_line])
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x, horizon_y - tree.y * 0.42), tree.y, t_shade])
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x - tree.y * 0.18, horizon_y - tree.y * 0.42 - tree.y * 0.22), tree.y * 0.72, t_light])
	_fill_circles(canvas, circles)

## 밤의 먼 빌딩 줄 — 어두운 실루엣에 불 켜진 창이 띄엄띄엄(창 자리는 빌딩마다 늘 같다). 삼각형 묶음 두 개
func _draw_night_city(canvas: CanvasItem, indices: PackedInt32Array) -> void:
	var mesh := LineMesh.new()
	var windows := LineMesh.new()
	for i in indices:
		var src: Rect2 = _city[i]
		var h: float = src.size.y * night_city_height
		var rect := Rect2(src.position.x, horizon_y - h, src.size.x, h + 2.0)
		mesh.add_fill(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), night_city)
		var cols: int = int((rect.size.x - 6.0) / 9.0)
		var rows: int = int((h - 8.0) / 11.0)
		for row in rows:
			for col in cols:
				# 빌딩·층·칸으로 정해지는 가짜 난수 — 판마다 같은 창에 불이 켜진다
				var roll: float = fposmod(sin(float(i * 97 + row * 13 + col * 7) * 12.9898) * 43758.5453, 1.0)
				if roll > night_window_ratio:
					continue
				var p := Vector2(rect.position.x + 4.0 + col * 9.0, rect.position.y + 5.0 + row * 11.0)
				var a: float = 0.55 + 0.45 * fposmod(roll * 7.0, 1.0)
				windows.add_fill(PackedVector2Array([p, p + Vector2(5.0, 0.0), p + Vector2(5.0, 6.0), p + Vector2(0.0, 6.0)]), Color(night_window, a))
	mesh.draw_on(canvas)
	windows.draw_on(canvas)

## 꽉 찬 원 여러 개([가운데, 반지름, 색])를 **삼각형 묶음 하나**로 그린다 — 앞에 넣은 원이 먼저 칠해진다.
## ⚠️ draw_circle은 원 하나가 그리기 한 번(draw call)이라, 나무·구름 수백 개를 그것으로 그리면 프레임이 반토막 났다(실측)
static func _fill_circles(canvas: CanvasItem, circles: Array) -> void:
	var mesh := LineMesh.new()
	for c in circles:
		mesh.add_disc(c[0], c[1], c[2])
	mesh.draw_on(canvas)

func _draw_ground(left: float, right: float, bottom: float) -> void:
	if bottom <= horizon_y:
		return
	# 보도(전체) → 도로(연석 왼쪽) 순으로 깐다. 멀수록 하늘빛이 섞여 흐려진다
	_grad_quad(left, right, horizon_y, bottom, _lit(walk_far), _lit(walk_near))
	var curb_bottom: float = _x_at(curb_x, bottom)
	var road_far_c: Color = _lit(road_far)
	var road_near_c: Color = _lit(road_near)
	draw_primitive(PackedVector2Array([Vector2(left, horizon_y), Vector2(vanish_x, horizon_y), Vector2(curb_bottom, bottom), Vector2(left, bottom)]),
		PackedColorArray([road_far_c, road_far_c, road_near_c, road_near_c]), PackedVector2Array())
	# 도로 표시 — 연석 옆 흰 실선 + 가운데 점선(땅에 붙은 사각형이라 앞으로 올수록 크다)
	_ground_strip(curb_x - 0.22, curb_x - 0.17, _lit(lane_color), bottom)
	_lane_dashes(bottom)
	# 연석 — 윗면(밝은 띠)과 도로 쪽 테두리
	_ground_strip(curb_x, curb_x + curb_width, _lit(curb_color), bottom)
	_ground_strip(curb_x - 0.014, curb_x, edge_line, bottom)
	_ground_strip(curb_x + curb_width, curb_x + curb_width + 0.008, _lit(tile_line.darkened(0.2)), bottom)
	_tile_lines(right, bottom)
	if night:
		# 건물 뒤 먼 길은 어둠 속 — 건물 그림 틈으로 보이는 땅이 환하면 낮처럼 보인다. 아랫단은 앞길로 부드럽게 녹인다
		var base_y: float = clampf(facade_ground_y, horizon_y + 16.0, bottom)
		_grad_quad(left, right, horizon_y - 1.0, base_y - 14.0, night_far_top, night_far_bottom)
		_grad_quad(left, right, base_y - 14.0, base_y + 2.0, night_far_bottom, Color(night_far_bottom, 0.0))
	else:
		# 지평선 언저리를 하늘빛으로 흐리게 — 바닥과 하늘이 칼같이 갈리지 않게
		_grad_quad(left, right, horizon_y - 1.0, horizon_y + 26.0, Color(sky_horizon, 0.85), Color(sky_horizon, 0.0))
	if bottom_shade > 0.0:
		_grad_quad(left, right, lerpf(horizon_y, bottom, 0.45), bottom, Color(0, 0, 0, 0), Color(0.05, 0.03, 0.08, bottom_shade))

## 앞길 색 — 밤이면 밤빛으로 살짝 물든다(낮엔 그대로)
func _lit(c: Color) -> Color:
	if not night or night_ground_tint <= 0.0:
		return c
	return Color(c.lerp(night_ground_color, night_ground_tint), c.a)

## 소실점으로 모이는 바닥 띠(월드 X 범위 x0~x1, 화면 아래까지)
func _ground_strip(x0: float, x1: float, color: Color, bottom: float) -> void:
	draw_primitive(PackedVector2Array([Vector2(vanish_x, horizon_y), Vector2(_x_at(x0, bottom), bottom), Vector2(_x_at(x1, bottom), bottom)]),
		PackedColorArray([color, color, color]), PackedVector2Array())

func _lane_dashes(bottom: float) -> void:
	var z_near: float = focal * camera_height / maxf(bottom - horizon_y, 1.0) + dolly
	var period: float = 1.7
	var dash: float = 0.85
	var k: int = int(floor((z_near - 1.0) / period))
	while true:
		var z0: float = k * period + 0.4
		var z1: float = z0 + dash
		k += 1
		if z1 - dolly < 0.3:
			continue
		if z0 - dolly > 70.0:
			break
		var a: Vector2 = _ground(lane_x, maxf(z0, dolly + 0.3))
		var b: Vector2 = _ground(lane_x + 0.07, maxf(z0, dolly + 0.3))
		var c: Vector2 = _ground(lane_x + 0.07, z1)
		var d: Vector2 = _ground(lane_x, z1)
		if a.y - d.y < 0.6:
			continue
		var lc: Color = _lit(lane_color)
		draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([lc, lc, lc, lc]), PackedVector2Array())

## 보도 타일 줄눈 — 세로(소실점으로 모임)는 지평선 쪽으로 옅어지고, 가로는 간격이 좁아지면 옅어진다.
## ⚠️ 줄눈은 200줄 가까이라 draw_polyline/draw_line으로 그으면 줄 하나가 그리기 한 번(draw call)이 되어 그것만으로
## 프레임이 반토막 났다(실측). 그래서 **삼각형 묶음**(`LineMesh`, 안티에일리어싱 가장자리 포함)으로 쌓아 두 번에 그린다.
## 세로 줄눈은 dolly와 상관없어서 화면 크기가 바뀔 때만 다시 쌓는다
func _tile_lines(right: float, bottom: float) -> void:
	var key: Array = [right, bottom, horizon_y, vanish_x, camera_height]
	if key != _column_key:
		_column_key = key
		_column_mesh = _tile_columns(right, bottom)
	_add_mesh(_column_mesh)
	var rows := LineMesh.new()
	var start_x: float = curb_x + curb_width
	var z_near: float = focal * camera_height / maxf(bottom - horizon_y, 1.0) + dolly
	var k: int = int(floor(z_near / tile_size))
	while k < 400:
		var z: float = k * tile_size
		k += 1
		if z - dolly < 0.3:
			continue
		var y: float = _y_at(z)
		var gap: float = y - _y_at(z + tile_size)
		if gap < 2.5:
			break
		var col := Color(tile_line, tile_line.a * clampf((gap - 2.5) / 16.0, 0.0, 1.0))
		rows.add_line(PackedVector2Array([Vector2(_x_at(start_x, y), y), Vector2(right, y)]), PackedColorArray([col, col]), 1.5)
	_add_mesh(rows)

## 세로 줄눈(소실점으로 모이는 선) — 지평선 쪽 끝은 투명하게
func _tile_columns(right: float, bottom: float) -> LineMesh:
	var mesh := LineMesh.new()
	var start_x: float = curb_x + curb_width
	var faint := Color(tile_line, 0.0)
	var mid_y: float = lerpf(horizon_y, bottom, 0.3)
	var n: int = 1
	while n < 200:
		var wx: float = start_x + n * tile_size
		n += 1
		var bx: float = _x_at(wx, bottom)
		var p_top := Vector2(_x_at(wx, horizon_y + 3.0), horizon_y + 3.0)
		if p_top.x > right:
			break
		mesh.add_line(PackedVector2Array([p_top, Vector2(_x_at(wx, mid_y), mid_y), Vector2(bx, bottom)]),
			PackedColorArray([faint, Color(tile_line, tile_line.a * 0.45), tile_line]), 1.6)
	return mesh

func _add_mesh(mesh: LineMesh) -> void:
	if mesh != null:
		mesh.draw_on(self)

## 위아래로 색이 바뀌는 가로 띠
func _grad_quad(left: float, right: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	if y1 - y0 < 0.5:
		return
	draw_primitive(PackedVector2Array([Vector2(left, y0), Vector2(right, y0), Vector2(right, y1), Vector2(left, y1)]),
		PackedColorArray([c0, c0, c1, c1]), PackedVector2Array())

## 월드 X가 같은 바닥 선이 화면 높이 y에서 지나는 x(이 선들은 전부 소실점으로 모인다)
func _x_at(world_x: float, y: float) -> float:
	return vanish_x + world_x * (y - horizon_y) / camera_height

## 깊이 z인 바닥의 화면 높이
func _y_at(z: float) -> float:
	return horizon_y + focal * camera_height / maxf(z - dolly, 0.05)

func _ground(world_x: float, z: float) -> Vector2:
	var d: float = maxf(z - dolly, 0.05)
	return Vector2(vanish_x + focal * world_x / d, horizon_y + focal * camera_height / d)

## 구름 한 덩이 — 한 번 그려 두고 자리만 옮긴다
class CloudDrawing extends Node2D:
	## 이 그림을 맡긴 ArrestBackdrop(무타입 — 바깥 스크립트 함수를 부르려고)
	var backdrop = null
	var puffs: Array = []
	var size: float = 1.0

	func _draw() -> void:
		if backdrop != null:
			backdrop._draw_cloud_on(self, puffs, size)

## 먼 나무·건물 — 보이는 것이 바뀔 때만 다시 그린다
class FarDrawing extends Node2D:
	## 이 그림을 맡긴 ArrestBackdrop(무타입 — 바깥 스크립트 함수를 부르려고)
	var backdrop = null

	func _draw() -> void:
		if backdrop != null:
			backdrop._draw_far_on(self)
