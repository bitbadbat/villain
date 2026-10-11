extends Node2D

## 연행 장면 조명(2026-10-11 사용자: "연행 장면에 라이팅이랑 쉐이딩 — 특히 번화가는 밤이라 어둡고 네온 사인이랑 불빛이 많잖아").
## 더하기(가산)로 그리는 빛 층이다. 장면(ArrestScene)이 두 장을 만든다:
##  - `GROUND` (건물 바로 위 · 사람 밑): 길에 비친 간판 빛(젖은 길처럼 세로로 길게) + 1층 가게 불빛이 보도에 쏟아진 자리
##    + 경광등이 건물 벽·길을 빨강/파랑으로 물들이는 빛
##  - `AIR` (사람 위): 경광등·전조등 둘레 번짐 — 밤엔 차 그림까지 어두워지므로 등이 이걸로 다시 빛난다
##  - `VIGNETTE` (사람 위, 번짐 밑): 화면 가장자리를 어둡게 곱한다(밤만) — 가운데 행렬로 눈이 간다
## 불빛 목록·세기는 맵마다 `ArrestBackdropConfig`(조명 묶음)에서 오고, 자리는 장면이 매 프레임 넣는 건물 위치·카메라로 원근에 맞춘다.
## 사람 몸의 윤곽광은 여기서 안 한다 — `ArrestLight.gdshader`(장면이 리그 조각에 붙인다)
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — 장면이 preload로 쓴다

enum Mode { GROUND, AIR, VIGNETTE }

var mode: int = Mode.GROUND

# ---- 장면이 매 프레임 넣는 값
var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 건물 그림의 화면 자리(그림 왼쪽 위)·배율·땅선(그림 px)·깊이(월드 z)
var building_pos: Vector2 = Vector2.ZERO
var building_scale: float = 1.0
var building_ground_px: float = 0.0
var building_z: float = 10.0
## 화면에 보이는 범위(Stage 좌표)
var view_rect: Rect2 = Rect2(0, 0, 1280, 720)
## 경찰차 `light_state()` 결과(경찰차 좌표 = Stage 좌표)
var siren: Dictionary = {}

# ---- 맵 설정(ArrestBackdropConfig)에서 오는 값 — `configure()`
var _rects: Array = []
var _colors: PackedColorArray = PackedColorArray()
var _reflection: float = 0.0
var _siren_power: float = 0.15
var _night: bool = false
## 가장자리 어둡기(0 = 안 그림) — 맵 설정 vignette
var _vignette: float = 0.0

## 1층 불빛으로 칠 높이 — 그림 땅선에서 이만큼(그림 px x 땅선 대비 비율) 안에 아랫변이 있으면 보도에 불빛을 쏟는다
const GROUND_FLOOR_RATIO := 0.24
## 보도에 쏟아지는 불빛이 길 쪽으로 뻗는 거리(월드, 캐릭터 키 = 1)
const SPILL_DEPTH := 1.5
## 길에 비친 빛이 뻗는 거리(월드)
const REFLECT_DEPTH := 3.2

var _radial: Texture2D = null
var _streak: Texture2D = null
var _vignette_tex: Texture2D = null

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL if mode == Mode.VIGNETTE else CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if mode != Mode.VIGNETTE:
		_radial = _make_radial()
		_streak = _make_streak()

func _process(_delta: float) -> void:
	queue_redraw()

## 맵 설정을 읽는다(건물 그림이 바뀔 때마다)
func configure(config: Resource) -> void:
	_rects = []
	_colors = PackedColorArray()
	_reflection = 0.0
	_siren_power = 0.15
	_night = false
	_vignette = 0.0
	if config == null:
		return
	var rects = config.get("light_rects")
	var colors = config.get("light_colors")
	if rects is Array and colors is PackedColorArray:
		for i in mini(rects.size(), colors.size()):
			_rects.append(rects[i])
			_colors.append(colors[i])
	_reflection = float(config.get("reflection")) if config.get("reflection") != null else 0.0
	_siren_power = float(config.get("siren_power")) if config.get("siren_power") != null else 0.15
	_night = bool(config.get("night"))
	_vignette = float(config.get("vignette")) if config.get("vignette") != null else 0.0
	if mode == Mode.VIGNETTE:
		_vignette_tex = _make_vignette(_vignette) if _vignette > 0.0 else null

func _draw() -> void:
	match mode:
		Mode.GROUND:
			_draw_ground_lights()
			_draw_siren_wash()
		Mode.AIR:
			_draw_siren_halo()
		Mode.VIGNETTE:
			if _vignette_tex != null:
				draw_texture_rect(_vignette_tex, view_rect, false)

# ---------------------------------------------------------------- 길·벽

func _draw_ground_lights() -> void:
	if _rects.is_empty():
		return
	var k: float = building_scale
	var base_y: float = building_pos.y + building_ground_px * k
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		var c: Color = _colors[i]
		var x0: float = building_pos.x + r.position.x * k
		var x1: float = building_pos.x + r.end.x * k
		if x1 < view_rect.position.x - 200.0 or x0 > view_rect.end.x + 200.0:
			continue
		var ground_floor: bool = r.end.y >= building_ground_px * (1.0 - GROUND_FLOOR_RATIO)
		if ground_floor:
			# 가게 안 불빛이 보도에 쏟아진다 — 넓고 진하고 짧게
			_ground_quad(x0, x1, base_y, SPILL_DEPTH, Color(c.r, c.g, c.b, c.a * 0.42))
		if _reflection > 0.0:
			# 길에 비친 간판 — 가운데로 좁고 길게(젖은 아스팔트 느낌)
			var mid: float = (x0 + x1) * 0.5
			var half: float = (x1 - x0) * (0.32 if not ground_floor else 0.42)
			_ground_quad(mid - half, mid + half, base_y, REFLECT_DEPTH, Color(c.r, c.g, c.b, c.a * _reflection))

## 건물 땅선(base_y)의 x0~x1에서 길 쪽(카메라 쪽)으로 depth만큼 뻗는 빛 판. 원근을 따라 소실점에서 멀어지며 넓어진다
func _ground_quad(x0: float, x1: float, base_y: float, depth: float, color: Color) -> void:
	var z_far: float = maxf(building_z - dolly, 0.05)
	var z_near: float = maxf(building_z - depth - dolly, 0.3)
	var s: float = z_far / z_near
	var y_near: float = horizon_y + focal * camera_height / z_near
	var pts := PackedVector2Array([
		Vector2(x0, base_y), Vector2(x1, base_y),
		Vector2(vanish_x + (x1 - vanish_x) * s, y_near), Vector2(vanish_x + (x0 - vanish_x) * s, y_near),
	])
	var cols := PackedColorArray([color, color, color, color])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	draw_primitive(pts, cols, uvs, _streak)

## 경광등이 번쩍일 때 건물 벽·길이 그 색으로 물든다(사람 밑에 그려서 사람은 윤곽광으로 따로 물든다)
func _draw_siren_wash() -> void:
	if siren.is_empty() or _siren_power <= 0.0:
		return
	var unit: float = float(siren.get("unit", 100.0))
	for key in ["red", "blue"]:
		if not bool(siren.get(key + "_on", false)):
			continue
		var c: Color = siren.get(key + "_color", Color.RED)
		var p: Vector2 = siren.get(key, Vector2.ZERO)
		# 넓게 번지는 빛 — 벽과 길을 다 덮을 만큼 크게
		var r: float = unit * 5.5
		draw_texture_rect(_radial, Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(c.r, c.g, c.b, 0.55 * _siren_power))
		# 벽에 닿은 진한 자리
		var r2: float = unit * 2.4
		draw_texture_rect(_radial, Rect2(p + Vector2(unit * 0.8, -unit * 0.4) - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(c.r, c.g, c.b, 0.5 * _siren_power))

# ---------------------------------------------------------------- 사람 위

func _draw_siren_halo() -> void:
	if siren.is_empty():
		return
	var unit: float = float(siren.get("unit", 100.0))
	var night_k: float = 1.0 if _night else 0.45
	for key in ["red", "blue"]:
		if not bool(siren.get(key + "_on", false)):
			continue
		var c: Color = siren.get(key + "_color", Color.RED)
		var p: Vector2 = siren.get(key, Vector2.ZERO)
		var r: float = unit * 1.1
		draw_texture_rect(_radial, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, 0.8 * night_k))
		var r2: float = unit * 0.35
		draw_texture_rect(_radial, Rect2(p - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1, 1, 1, 0.7 * night_k))
	if _night:
		# 전조등 — 어두운 차 앞에서 노랗게 빛난다
		var hc: Color = siren.get("head_color", Color(1, 0.95, 0.75))
		for key in ["head_l", "head_r"]:
			var p: Vector2 = siren.get(key, Vector2.ZERO)
			var r: float = unit * 0.5
			draw_texture_rect(_radial, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(hc.r, hc.g, hc.b, 0.75))
			var r2: float = unit * 0.16
			draw_texture_rect(_radial, Rect2(p - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1, 1, 1, 0.8))

# ---------------------------------------------------------------- 그림

## 가운데가 가장 밝고 둘레로 부드럽게 사라지는 원
static func _make_radial() -> Texture2D:
	var n: int = 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## 가운데 흰색 → 가장자리 남색(곱하기용, 곱하기는 흰색 = 그대로). strength 1이면 가장자리가 EDGE 색까지 어두워진다.
## 가로로 긴 화면에 맞춰 타원으로 퍼진다
static func _make_vignette(strength: float) -> Texture2D:
	var w: int = 160
	var h: int = 90
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var edge := Color(1, 1, 1).lerp(Color(0.32, 0.34, 0.5), clampf(strength, 0.0, 1.0))
	for y in h:
		for x in w:
			var d: float = Vector2((x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0).length()
			var k: float = smoothstep(0.55, 1.35, d)
			img.set_pixel(x, y, Color(1, 1, 1).lerp(edge, k))
	return ImageTexture.create_from_image(img)

## 위(건물 쪽)가 진하고 아래(카메라 쪽)로 사라지며, 좌우 가장자리가 부드러운 띠
static func _make_streak() -> Texture2D:
	var w: int = 32
	var h: int = 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: float = pow(1.0 - float(y) / float(h - 1), 1.7)
		for x in w:
			var u: float = (x + 0.5) / float(w) * 2.0 - 1.0
			var bell: float = clampf(1.0 - u * u, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, bell * bell * v))
	return ImageTexture.create_from_image(img)
