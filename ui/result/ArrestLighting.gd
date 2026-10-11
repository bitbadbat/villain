extends Node2D

## 연행 장면 조명(2026-10-11 사용자: "연행 장면에 라이팅이랑 쉐이딩 — 특히 번화가는 밤이라 어둡고 네온 사인이랑 불빛이 많잖아").
## 더하기(가산)로 그리는 빛 층이다. 장면(ArrestScene)이 두 장을 만든다:
##  - `GROUND` (건물 바로 위 · 사람 밑): 길에 비친 간판 빛(젖은 길처럼 세로로 길게) + 1층 가게 불빛이 보도에 쏟아진 자리
##    + 경광등이 건물 벽·길을 빨강/파랑으로 물들이는 빛
##  - `AIR` (사람 위): 경광등·전조등 둘레 번짐 — 밤엔 차 그림까지 어두워지므로 등이 이걸로 다시 빛난다
##  - `VIGNETTE` (사람 위, 번짐 밑): 화면 가장자리를 어둡게 곱한다(밤만) — 가운데 행렬로 눈이 간다
##  - `SHADE` (건물 바로 위 · GROUND 밑, 곱하기): 낮 그림 명암 — 건물 위아래·해 반대쪽 어둡기 + 건물·나무 그늘이 앞길에 드리운 띠
## 낮 그림(2026-10-11 사용자: "놀이터면 나무 사이사이로 햇빛이 새어나오는")은 GROUND에 빛줄기·땅의 햇빛 얼룩·유리 반짝임·창 불빛(깜빡임)을 더 그린다.
## 불빛 목록·세기는 맵마다 `ArrestBackdropConfig`(조명 묶음)에서 오고, 자리는 장면이 매 프레임 넣는 건물 위치·카메라로 원근에 맞춘다.
## 사람 몸의 윤곽광은 여기서 안 한다 — `ArrestLight.gdshader`(장면이 리그 조각에 붙인다)
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — 장면이 preload로 쓴다

enum Mode { GROUND, AIR, VIGNETTE, SHADE }

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
var building_width: float = 1536.0
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
# 낮 그림 — ArrestBackdropConfig "햇빛·그늘" 묶음
var _facade_top: Color = Color.WHITE
var _facade_bottom: Color = Color.WHITE
var _facade_side: float = 0.0
var _ground_shade: Color = Color.WHITE
var _ground_shade_depth: float = 1.0
var _sun_color: Color = Color(1, 1, 1, 0)
var _sun_dir: Vector2 = Vector2(0.45, 1.0)
var _shafts: Array = []
var _dapple: float = 0.0
## 땅 햇빛 얼룩 — [건물 폭 비율 u, 깊이(월드), 크기, 위상]
var _spots: Array = []
var _glints: Array = []
var _glint_period: float = 2.8
var _light_glow: float = 0.0
var _flicker: PackedInt32Array = PackedInt32Array()
var _t: float = 0.0

## 1층 불빛으로 칠 높이 — 그림 땅선에서 이만큼(그림 px x 땅선 대비 비율) 안에 아랫변이 있으면 보도에 불빛을 쏟는다
const GROUND_FLOOR_RATIO := 0.24
## 보도에 쏟아지는 불빛이 길 쪽으로 뻗는 거리(월드, 캐릭터 키 = 1)
const SPILL_DEPTH := 1.5
## 길에 비친 빛이 뻗는 거리(월드)
const REFLECT_DEPTH := 3.2

var _radial: Texture2D = null
var _streak: Texture2D = null
var _vignette_tex: Texture2D = null
var _shaft_tex: Texture2D = null
var _spot_tex: Texture2D = null

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL if mode == Mode.VIGNETTE or mode == Mode.SHADE else CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if mode == Mode.GROUND or mode == Mode.AIR:
		_radial = _make_radial()
		_streak = _make_streak()
		_shaft_tex = _make_shaft()
		_spot_tex = _make_spot()

func _process(delta: float) -> void:
	_t += minf(delta, 0.05)
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
	_facade_top = config.get("facade_top")
	_facade_bottom = config.get("facade_bottom")
	_facade_side = float(config.get("facade_side"))
	_ground_shade = config.get("ground_shade")
	_ground_shade_depth = float(config.get("ground_shade_depth"))
	_sun_color = config.get("sun_color")
	# 빛은 rim_dir 쪽(해)에서 온다 — 빛줄기는 그 반대로 뻗는다
	var rim_dir: Vector2 = config.get("rim_dir")
	_sun_dir = -rim_dir.normalized() if rim_dir.length() > 0.01 else Vector2(0.45, 1.0).normalized()
	_shafts = config.get("sun_shafts")
	_dapple = float(config.get("dapple"))
	_glints = config.get("glint_rects")
	_glint_period = maxf(float(config.get("glint_period")), 1.0)
	_light_glow = float(config.get("light_glow"))
	_flicker = config.get("light_flicker")
	_spots = []
	if _dapple > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 70:
			_spots.append([rng.randf(), rng.randf_range(0.04, _ground_shade_depth), rng.randf_range(0.6, 1.4), rng.randf() * TAU])
	if mode == Mode.VIGNETTE:
		_vignette_tex = _make_vignette(_vignette) if _vignette > 0.0 else null

func _draw() -> void:
	match mode:
		Mode.GROUND:
			_draw_shafts()
			_draw_spots()
			_draw_light_glow()
			_draw_glints()
			_draw_ground_lights()
			_draw_siren_wash()
		Mode.SHADE:
			_draw_facade_grade()
			_draw_ground_shade()
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
		c.a *= _flicker_level(i)
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

# ---------------------------------------------------------------- 낮 그림 — 명암(SHADE, 곱하기)

## 건물 그림 위아래(해 받는 위 / 그늘진 아래)와 해 반대쪽 끝 어둡기 — 네 귀 색으로 한 판에
func _draw_facade_grade() -> void:
	if _facade_top == Color.WHITE and _facade_bottom == Color.WHITE and _facade_side <= 0.0:
		return
	var k: float = building_scale
	var x0: float = building_pos.x
	var x1: float = building_pos.x + building_width * k
	var y1: float = building_pos.y + building_ground_px * k
	# 빛줄기가 오른쪽으로 뻗으면 해는 왼쪽 — 오른쪽 끝이 어둡다
	var left_k: float = 1.0 - _facade_side if _sun_dir.x < 0.0 else 1.0
	var right_k: float = 1.0 - _facade_side if _sun_dir.x > 0.0 else 1.0
	var pts := PackedVector2Array([Vector2(x0, building_pos.y), Vector2(x1, building_pos.y), Vector2(x1, y1), Vector2(x0, y1)])
	draw_polygon(pts, PackedColorArray([_dim(_facade_top, left_k), _dim(_facade_top, right_k), _dim(_facade_bottom, right_k), _dim(_facade_bottom, left_k)]))

## 건물·나무 그늘이 앞길에 드리운 띠 — 건물 밑이 가장 진하고 길 쪽으로 사라진다
func _draw_ground_shade() -> void:
	if _ground_shade == Color.WHITE or _ground_shade_depth <= 0.0:
		return
	var base_y: float = building_pos.y + building_ground_px * building_scale
	var x0: float = view_rect.position.x - 400.0
	var x1: float = view_rect.end.x + 400.0
	var z_far: float = maxf(building_z - dolly, 0.05)
	var z_near: float = maxf(building_z - _ground_shade_depth - dolly, 0.3)
	var s: float = z_far / z_near
	var y_near: float = horizon_y + focal * camera_height / z_near
	var pts := PackedVector2Array([Vector2(x0, base_y), Vector2(x1, base_y),
		Vector2(vanish_x + (x1 - vanish_x) * s, y_near), Vector2(vanish_x + (x0 - vanish_x) * s, y_near)])
	draw_polygon(pts, PackedColorArray([_ground_shade, _ground_shade, Color.WHITE, Color.WHITE]))

static func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)

# ---------------------------------------------------------------- 낮 그림 — 빛(GROUND, 더하기)

## 나무 틈으로 새는 빛줄기 — 그림 속 틈에서 해 반대쪽으로 뻗어 땅에 닿고, 닿은 자리에 납작한 햇빛 웅덩이. 잎이 흔들리듯 밝기가 일렁인다
func _draw_shafts() -> void:
	if _shafts.is_empty() or _sun_color.a <= 0.0 or _sun_dir.y <= 0.05:
		return
	var k: float = building_scale
	var base_y: float = building_pos.y + building_ground_px * k
	var across := Vector2(_sun_dir.y, -_sun_dir.x)
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for i in _shafts.size():
		var shaft: Vector3 = _shafts[i]
		var start: Vector2 = building_pos + Vector2(shaft.x, shaft.y) * k
		# 땅선을 조금 넘겨 앞길까지 닿게
		var end: Vector2 = start + _sun_dir * ((base_y + 14.0 * k - start.y) / _sun_dir.y)
		var w0: float = shaft.z * k
		var w1: float = w0 * 1.8
		var flick: float = 0.72 + 0.18 * sin(_t * 0.9 + i * 1.7) + 0.1 * sin(_t * 2.3 + i * 2.9)
		var c := Color(_sun_color.r, _sun_color.g, _sun_color.b, _sun_color.a * flick)
		var pts := PackedVector2Array([start - across * w0 * 0.5, start + across * w0 * 0.5, end + across * w1 * 0.5, end - across * w1 * 0.5])
		draw_primitive(pts, PackedColorArray([c, c, c, c]), uvs, _shaft_tex)
		var pool := Vector2(w1 * 1.2, w1 * 0.28)
		draw_texture_rect(_radial, Rect2(end - pool, pool * 2.0), false, Color(c.r, c.g, c.b, c.a * 1.2))

## 나뭇잎 사이 햇빛 얼룩 — 건물 앞 그늘 띠 안에 흩어진 납작한 빛 점이 천천히 일렁인다(원근을 따라 앞일수록 크다)
func _draw_spots() -> void:
	if _spots.is_empty():
		return
	var k: float = building_scale
	var z_far: float = maxf(building_z - dolly, 0.05)
	for spot in _spots:
		var x_base: float = building_pos.x + float(spot[0]) * building_width * k
		var z_near: float = maxf(building_z - float(spot[1]) - dolly, 0.3)
		var s: float = z_far / z_near
		var p := Vector2(vanish_x + (x_base - vanish_x) * s, horizon_y + focal * camera_height / z_near)
		if p.x < view_rect.position.x - 80.0 or p.x > view_rect.end.x + 80.0:
			continue
		var phase: float = spot[3]
		p.x += sin(_t * 0.7 + phase) * 5.0 * s
		var r: float = 34.0 * float(spot[2]) * s * k
		var a: float = _dapple * (0.5 + 0.32 * sin(_t * 1.3 + phase * 2.0) + 0.18 * sin(_t * 3.1 + phase))
		draw_texture_rect(_spot_tex, Rect2(p - Vector2(r, r * 0.32), Vector2(r * 2.0, r * 0.64)), false, Color(_sun_color.r, _sun_color.g, _sun_color.b, a))

## 낮 그림 속 불빛(light_rects) — 창 안이 그 색으로 밝고 둘레로 번진다. 깜빡이는 불(light_flicker)은 모니터처럼 장면마다 밝기가 튄다
func _draw_light_glow() -> void:
	if _light_glow <= 0.0:
		return
	var k: float = building_scale
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		var c: Color = _colors[i]
		var a: float = c.a * _light_glow * _flicker_level(i)
		var on_screen := Rect2(building_pos + r.position * k, r.size * k)
		draw_rect(on_screen, Color(c.r, c.g, c.b, a * 0.5))
		draw_texture_rect(_radial, on_screen.grow(maxf(on_screen.size.x, on_screen.size.y) * 0.35), false, Color(c.r, c.g, c.b, a * 0.75))

## 0~1 밝기 — 깜빡이는 불이면 1/3초마다 다른 밝기(화면이 바뀌는 모니터) + 잔떨림, 아니면 1
func _flicker_level(i: int) -> float:
	if not _flicker.has(i):
		return 1.0
	var cut: float = floorf(_t * 3.0)
	var level: float = fposmod(sin(cut * 12.9898 + i * 78.233) * 43758.5453, 1.0)
	return 0.5 + 0.4 * level + 0.1 * sin(_t * 23.0 + i)

## 유리에 스치는 반짝임 — 비스듬한 밝은 띠가 유리 네모 안을 한 번 훑고 지나간다(유리마다 박자를 엇갈려)
func _draw_glints() -> void:
	if _glints.is_empty():
		return
	var k: float = building_scale
	var sweep: float = 0.8
	for i in _glints.size():
		var r: Rect2 = _glints[i]
		var box := Rect2(building_pos + r.position * k, r.size * k)
		var u: float = fposmod(_t + i * _glint_period * 0.37, _glint_period) / sweep
		if u > 1.0:
			continue
		var slant: float = box.size.y * 0.45
		var half: float = maxf(box.size.x * 0.07, 4.0)
		var cx: float = lerpf(box.position.x - slant - half, box.end.x + slant + half, u)
		var a: float = 0.34 * sin(u * PI)
		var corners := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		# 굵은 띠 하나 + 뒤따르는 가는 띠 하나
		for band in [[0.0, half, a], [half * 3.2, half * 0.35, a * 0.8]]:
			var x: float = cx - float(band[0])
			var w: float = band[1]
			var strip := PackedVector2Array([Vector2(x - w + slant, box.position.y), Vector2(x + w + slant, box.position.y),
				Vector2(x + w - slant, box.end.y), Vector2(x - w - slant, box.end.y)])
			for poly in Geometry2D.intersect_polygons(strip, corners):
				# 잘린 조각이 거의 0이면 삼각분할 에러가 난다(CLAUDE.md 함정) — 넓이가 있는 것만
				if absf(_area(poly)) > 2.0:
					draw_colored_polygon(poly, Color(1, 1, 1, float(band[2])))

static func _area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return s * 0.5

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

## 빛줄기 — 가로(u)는 가운데가 밝은 종 모양, 세로(v)는 틈에서 금방 밝아졌다가 땅으로 갈수록 옅어진다
static func _make_shaft() -> Texture2D:
	var w: int = 32
	var h: int = 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: float = float(y) / float(h - 1)
		var along: float = smoothstep(0.0, 0.14, v) * lerpf(1.0, 0.35, v)
		for x in w:
			var u: float = (x + 0.5) / float(w) * 2.0 - 1.0
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - u * u, 0.0, 1.0), 1.6) * along))
	return ImageTexture.create_from_image(img)

## 햇빛 얼룩 — 속은 고르게 밝고 테두리만 부드럽다(그냥 번짐 원이면 흐릿한 얼룩이라 "빛 점"으로 안 읽힌다)
static func _make_spot() -> Texture2D:
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.55, 1.0, d)))
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
