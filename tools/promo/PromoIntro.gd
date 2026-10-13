extends Node

## 홍보 영상 앞부분(2026-10-13). Movie Maker로 찍는다:
##   godot --path . --write-movie out.avi --fixed-fps 60 res://tools/promo/PromoIntro.tscn
## 시간은 전부 프레임 기준(_t)이라 녹화 속도와 상관없이 같은 영상이 나온다.
##
## 1장면: 검은 화면 질문 → 흐려지며 놀이터 → "사람한테 비비탄 쏘는 금쪽이" + 허공에 비비탄
## 2장면: 흐려지며 번화가 → "길거리에 토하는 사람" + 주정뱅이(이미 1모금)가 한 모금 더 마시고 토함
## 3장면: 흐려지며 악플러의 집 → "집구석에서 악플 다는 사람" + 악플러는 가만히 서 있음
## 4장면: 흐려지며 번화가 2층(편의점 지붕) → "아무 데서나 담배 피우는 사람" + 일진이 담배(스킬1)
## 5장면: 흐려지며 지하철 승강장 → "단소로 지하철을 공연장으로 만드는 사람" + 지하철 아저씨는 가만히 서 있음
##
## ⚠️ AI 조종기는 떼지 말고 is_active만 끈다 — 캐릭터 물리(중력·착지·자세)는 조종기가 매 프레임 돌려 준다.
## 통째로 떼면 첫 프레임 달리던 자세로 얼어붙는다(목이 꺾여 보이던 원인).
## ⚠️ 끄는 건 **맵을 붙인 바로 그 자리에서**(첫 프레임 전). 한 프레임 늦으면 AI가 한 번 움직여 하얀 스피드 라인이 남는다
## ⚠️ 땅은 원래 게임 화면에서와 같은 높이 비율(번화가 약 92%)에 둔다 — 더 위에 두면 땅 그림 밑(돌 블록 등)이 드러난다

@export var question: String = "당신의 주위에도 이런 사람이 있나요?"
@export var captions: PackedStringArray = ["사람한테 비비탄 쏘는 금쪽이", "길거리에 토하는 사람", "집구석에서 악플 다는 사람", "아무 데서나 담배 피우는 사람", "단소로 지하철을 공연장으로 만드는 사람"]
## 질문이 떠오르는 구간 / 첫 흐림 시작 / 흐림이 가장 셀 때 / 다시 또렷해짐
@export var t_question_in: Vector2 = Vector2(0.3, 1.1)
@export var t_blur_start: float = 2.6
@export var t_blur_peak: float = 3.4
@export var t_clear: float = 4.1
@export var t_fire: float = 4.6
## 다음 장면으로 넘어가는 흐림이 가장 센 시각(여기서 맵을 바꾼다). 앞뒤로 swap_half초 동안 흐려졌다 또렷해진다
@export var t_swaps: PackedFloat32Array = [7.5, 11.7, 15.3, 19.3]
@export var swap_half: float = 0.7
@export var t_drink: float = 8.7
@export var t_vomit: float = 10.2
@export var t_smoke: float = 16.6
@export var t_end: float = 23.5
@export var max_blur_px: float = 14.0
## 맵 카메라 배율에 곱할 값 / 화면 가운데가 캐릭터에서 얼마나 떨어질지 / 화면이 드러난 뒤 오른쪽으로 흘러가는 속도(월드 px/초)
@export var zoom_mult: float = 2.4
@export var cam_offset: Vector2 = Vector2(30, -45)
@export var cam_pan_speed: float = 22.0
## 자막 글자 크기(처음 46의 1.2배)
@export var caption_size: int = 55
## 장면별 자막 윗변(화면 높이 비율). 지하철은 덜 확대해서 아저씨가 위로 올라가므로 더 위
@export var caption_tops: PackedFloat32Array = [0.33, 0.33, 0.33, 0.33, 0.15]
## 캐릭터를 세울 자리 = (x, **발을 딛는 면의 y**) — 그 면에 발을 딱 붙여 놓는다(위에서 떨어뜨리면 장면마다 착지 찌그러짐이 보였다). 놀이터는 미끄럼틀 끝과 그네 사이(그네 앞에 서면 그네에 맞아 경직돼 스킬이 막힌다).
## 악플러는 컴퓨터가 놓인 가운데 발판 위, 컴퓨터 왼쪽
@export var shooter_pos: Vector2 = Vector2(-360, 280)
@export var drunk_pos: Vector2 = Vector2(-300, 286)
@export var akpeulleo_pos: Vector2 = Vector2(-100, 12)
## 일진은 번화가 편의점 지붕 발판(윗면 y -32, x 425~899) 위, 쓰레기통(x 608) 왼쪽
@export var iljin_pos: Vector2 = Vector2(500, -32)
## 지하철 아저씨는 왼쪽 의자(앉는 판 윗면 y 155) 위 — 선로 바닥에 세우면 몸이 화면 맨 아래라 자막과 겹쳤다
@export var subway_pos: Vector2 = Vector2(-280, 155)
## 지하철만 땅 아래를 더 보여 준다(2026-10-13 사용자 "맵 아래까지")
@export var subway_below_px: float = 40.0
## 지하철만 덜 확대하고(배율 x 이 값) 카메라를 바닥 한계까지 내린다 — 의자 위 아저씨와 아래 선로가 같이 보이게
@export var subway_zoom_scale: float = 0.7

var _t: float = 0.0
var _scene: int = 0
var _actor: Fighter
var _map: Node
var _pan_from: float = 0.0
var _done: Dictionary = {}
var _black: ColorRect
var _question: Label
var _blur: ShaderMaterial
var _captions: Array[Label] = []
var _cam: Camera2D
var _cam_zoom: Vector2 = Vector2.ONE
## 이 장면 땅 윗면(월드 y)과, 원래 게임 화면에서 그 땅이 화면 높이의 몇 % 자리에 있었는지
var _ground_y: float = 280.0
var _ground_frac: float = 1.0
## 켜면 카메라 높이를 캐릭터 대신 "땅 아래를 보여 줄 수 있는 가장 낮은 자리"에 둔다
var _hug_bottom: bool = false

func _ready() -> void:
	_build_overlay()
	_pan_from = t_blur_start
	await _load_scene(GameState.MAPS["놀이터"], GameState.CHARACTERS["금쪽이"], shooter_pos, 280.0)

## 맵을 띄우고 캐릭터 하나만 남겨 세운 뒤 카메라를 넘겨받는다
## below_px: 원래 화면보다 땅 아래를 이만큼(월드 px) 더 보여 준다
func _load_scene(map_path: String, character: String, pos: Vector2, ground_y: float, below_px: float = 0.0, zoom_scale: float = 1.0, hug_bottom: bool = false) -> void:
	GameState.game_mode = "attract"
	GameState.p1_character_path = character
	GameState.p2_character_path = character
	if _map:
		_map.queue_free()
	_actor = null
	_map = load(map_path).instantiate()
	# 구경 모드 Stage는 _ready에서 바로 두 캐릭터를 세우고 AI를 붙인다 — add_child가 끝나면 이미 있다
	add_child(_map)
	var fighters: Array = _map.find_children("*", "Fighter", true, false)
	for f in fighters:
		for c in f.get_children():
			if c is AIController:
				c.is_active = false
	var actor: Fighter = fighters[0]
	actor.facing = 1
	actor.velocity = Vector2.ZERO
	actor.global_position = Vector2(pos.x, pos.y - _feet_offset(actor))
	# 2P는 숨겨서 바로 뒤에 둔다 — 판정도 꺼서 아무것도 안 맞는다
	var other: Fighter = fighters[1]
	other.visible = false
	other.process_mode = Node.PROCESS_MODE_DISABLED
	other.global_position = actor.global_position + Vector2(-60, 0)
	for a in other.find_children("*", "Area2D", true, false):
		a.set_deferred("monitorable", false)
		a.set_deferred("monitoring", false)
	await get_tree().process_frame
	# 카메라는 맵 스크립트를 끄고 이쪽이 직접 잡는다
	_cam = get_viewport().get_camera_2d()
	if _cam:
		# 맵 카메라가 처음 잡은 화면에서 땅이 몇 % 높이에 있었는지 — 확대해도 땅을 그 높이보다 위로 안 올린다(땅 그림 밑이 드러나지 않게)
		var view_h0: float = get_viewport().get_visible_rect().size.y / _cam.zoom.y
		var top0: float = _cam.get_screen_center_position().y - view_h0 * 0.5
		_ground_y = ground_y + below_px
		_ground_frac = clampf((ground_y - top0) / view_h0, 0.0, 1.0)
		_cam_zoom = _cam.zoom * zoom_mult * zoom_scale
		_hug_bottom = hug_bottom
		_cam.set_process(false)
		_cam.set_physics_process(false)
		_cam.position_smoothing_enabled = false
		_cam.drag_horizontal_enabled = false
		_cam.drag_vertical_enabled = false
		for side in ["limit_left", "limit_top"]:
			_cam.set(side, -100000)
		for side in ["limit_right", "limit_bottom"]:
			_cam.set(side, 100000)
	_actor = actor

## 원점에서 몸 판정 아래 끝(발바닥)까지의 거리
func _feet_offset(actor: Fighter) -> float:
	for c in actor.get_children():
		if c is CollisionShape2D and c.shape:
			var r: Rect2 = c.shape.get_rect()
			return c.position.y + r.end.y
	return 30.0

## 번화가: 택시·쓰레기통이 끼어들지 않게 멈추고, 주정뱅이를 "이미 한 모금" 상태로 만든다(마시는 동작·소리 없이)
func _prepare_downtown() -> void:
	_freeze_nodes(["Taxi", "TrashCans"])
	var drink: Skill = _actor.skill_1
	_actor.custom_data["drink_stacks"] = 1
	_actor.set_modifier("move_speed_multiplier", "drink_stacks", 1.0 - drink.move_speed_penalty_per_stack)
	var redness: float = 1.0 / float(drink.max_stacks) * drink.max_redness
	_actor.set_tint("drunk", Color(1.0, 1.0 - redness, 1.0 - redness))
	var visual: Node = _actor.get_node_or_null("Visual")
	if visual and visual.has_method("set_drunk_head"):
		visual.set_drunk_head(true)

## 악플러의 집: 암전·엄마가 끼어들지 않게 멈춘다
func _prepare_trash_room() -> void:
	_freeze_nodes(["Blackout", "MomDoorGimmick"])

func _freeze_nodes(names: Array) -> void:
	for node_name in names:
		var n: Node = _map.get_node_or_null(node_name)
		if n:
			n.process_mode = Node.PROCESS_MODE_DISABLED

func _build_overlay() -> void:
	var batang := SystemFont.new()
	batang.font_names = PackedStringArray(["Batang", "바탕"])
	# 아래층: 검은 화면 + 질문(흐림에 같이 먹힌다)
	var under := CanvasLayer.new()
	under.layer = 50
	add_child(under)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(_black)
	_question = _make_label(question, batang, 52)
	_question.modulate.a = 0.0
	under.add_child(_question)
	# 가운데층: 화면 전체 흐림
	var mid := CanvasLayer.new()
	mid.layer = 51
	add_child(mid)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	mid.add_child(copy)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur = ShaderMaterial.new()
	_blur.shader = preload("res://tools/promo/PromoBlur.gdshader")
	rect.material = _blur
	mid.add_child(rect)
	# 위층: 자막(항상 또렷)
	var top := CanvasLayer.new()
	top.layer = 52
	add_child(top)
	for i in captions.size():
		var l := _make_label(captions[i], batang, caption_size)
		# 캐릭터 머리 위, 화면 한가운데 가까이(2026-10-13 사용자). 장면마다 높이를 따로 줄 수 있다
		var cap_top: float = caption_tops[i] if i < caption_tops.size() else 0.33
		l.anchor_top = cap_top
		l.anchor_bottom = cap_top + 0.12
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 10)
		l.modulate.a = 0.0
		top.add_child(l)
		_captions.append(l)

func _make_label(text: String, font: Font, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	return l

func _process(delta: float) -> void:
	_t += minf(delta, 0.05)
	_update_camera()
	# 1장면 들어가기
	_question.modulate.a = _ramp(_t, t_question_in.x, t_question_in.y) * (1.0 - _ramp(_t, t_blur_start, t_blur_peak))
	_black.color.a = 1.0 - _ramp(_t, t_blur_start + 0.2, t_blur_peak)
	var blur: float = _ramp(_t, t_blur_start, t_blur_peak) * (1.0 - _ramp(_t, t_blur_peak, t_clear))
	# 장면 넘어가기 — 흐려졌다가 가장 셀 때 맵을 바꾸고 다시 또렷해진다
	for peak in t_swaps:
		blur = maxf(blur, _ramp(_t, peak - swap_half, peak) * (1.0 - _ramp(_t, peak, peak + swap_half)))
	_blur.set_shader_parameter("radius_px", max_blur_px * blur)
	# 자막 — i번 장면은 그 장면이 또렷해질 때 떠서 다음 흐림이 시작되면 사라진다
	for i in _captions.size():
		var shown_from: float = t_blur_peak if i == 0 else t_swaps[i - 1]
		var fade_in: float = _ramp(_t, shown_from + 0.2, shown_from + swap_half)
		var fade_out: float = 1.0
		if i < t_swaps.size():
			fade_out = 1.0 - _ramp(_t, t_swaps[i] - swap_half, t_swaps[i] - 0.2)
		_captions[i].modulate.a = fade_in * fade_out
	if _once("fire", t_fire) and _actor:
		_actor.facing = 1
		_actor.use_skill_2()
	for i in t_swaps.size():
		if _once("swap%d" % i, t_swaps[i]):
			_scene = i + 1
			_pan_from = t_swaps[i]
			_swap_to(i + 1)
	if _scene == 1 and _actor:
		if _once("drink", t_drink):
			_actor.use_skill_1()
		if _once("vomit", t_vomit):
			_actor.facing = 1
			_actor.use_skill_2()
	if _scene == 3 and _actor and _once("smoke", t_smoke):
		_actor.facing = 1
		_actor.use_skill_1()
	# 확인용: `-- shots=<폴더>` 를 주면 0.5초마다 스냅샷, `dense=10.1` 처럼 주면 그 시각부터 0.5초 동안은 3프레임마다
	var frame: int = roundi(_t * 60.0)
	var shots: String = _arg("shots")
	var dense: float = float(_arg("dense")) if _arg("dense") != "" else -1.0
	var dense_now: bool = dense >= 0.0 and _t >= dense and _t < dense + 0.5 and frame % 3 == 0
	if shots != "" and (frame % 30 == 0 or dense_now):
		get_viewport().get_texture().get_image().save_png("%s/t%05.2f.png" % [shots, _t])
	if _t >= t_end:
		get_tree().quit()

## 캐릭터를 따라가며 오른쪽으로 천천히 흐르되, 높이는 맵 카메라의 위아래 한계 안에서만
func _update_camera() -> void:
	if not (_cam and is_instance_valid(_cam) and _actor):
		return
	_cam.zoom = _cam_zoom
	var want: Vector2 = _actor.global_position + cam_offset + Vector2(cam_pan_speed * maxf(_t - _pan_from, 0.0), 0.0)
	# 땅이 원래 게임 화면과 같은 높이 비율보다 위로 올라오지 않게(= 그 아래 그림이 더 드러나지 않게)
	var view_h: float = get_viewport().get_visible_rect().size.y / _cam_zoom.y
	var lowest: float = _ground_y - (_ground_frac - 0.5) * view_h
	want.y = lowest if _hug_bottom else minf(want.y, lowest)
	_cam.global_position = want

func _swap_to(scene: int) -> void:
	if scene == 1:
		await _load_scene(GameState.MAPS["번화가"], GameState.CHARACTERS["주정뱅이"], drunk_pos, 286.0)
		_prepare_downtown()
	elif scene == 2:
		await _load_scene(GameState.MAPS["악플러의 집"], GameState.CHARACTERS["악플러"], akpeulleo_pos, 280.0)
		_prepare_trash_room()
	elif scene == 3:
		await _load_scene(GameState.MAPS["번화가"], GameState.CHARACTERS["일진"], iljin_pos, 286.0)
		_freeze_nodes(["Taxi", "TrashCans"])
	elif scene == 4:
		await _load_scene(GameState.MAPS["지하철역"], GameState.CHARACTERS["지하철 아저씨"], subway_pos, 300.0, subway_below_px, subway_zoom_scale, true)
		# 열차가 끼어들지 않게
		_freeze_nodes(["DecoSubwayTrain"])

func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""

## 그 시각을 처음 넘은 프레임에만 true
func _once(key: String, at: float) -> bool:
	if _done.has(key) or _t < at:
		return false
	_done[key] = true
	return true

func _ramp(t: float, a: float, b: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - a) / maxf(b - a, 0.001), 0.0, 1.0))
