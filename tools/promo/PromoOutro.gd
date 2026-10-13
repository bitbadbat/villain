extends Node

## 홍보 영상 뒷부분(2026-10-13) — 앞부분 `PromoIntro` 다음에 이어 붙인다. Movie Maker로 찍는다:
##   godot --path . --write-movie out.avi --fixed-fps 60 res://tools/promo/PromoOutro.tscn
## 시간은 전부 프레임 기준(_t).
##
## 1) 검은 화면 "그들이"(딱) → "격돌합니다"가 오른쪽에서 날아와 옆에 부딪힘(화면 흔들림)
## 2) 빌런끼리 싸우는 장면(+ 헬스장 운동 + 궁극기 둘) — 길이는 `PromoFights.length_of` (`PromoFights`가 맡는다)
## 3) 게임 로고

const FIGHTS := preload("res://tools/promo/PromoFights.gd")

@export var word_1: String = "그들이"
@export var word_2: String = "격돌합니다"
@export var word_size: int = 96
## "그들이"가 뜨는 시각 / "격돌합니다"가 날아오기 시작 / 부딪히는 시각 / 글자 화면 끝
@export var t_word_1: float = 0.35
@export var t_word_2_start: float = 0.95
@export var t_word_2_hit: float = 1.12
@export var t_words_end: float = 2.3
@export var logo_len: float = 3.5
@export var logo_scale: float = 1.7

var _t: float = 0.0
var _done: Dictionary = {}
var _black: ColorRect
var _words: Control
var _w1: Label
var _w2: Label
var _flash: ColorRect
var _logo_layer: CanvasLayer
var _logo: Control
var _fights: Node
var _fight_index: int = -1

func _ready() -> void:
	# 궁극기 컷인이 트리를 멈춰도(get_tree().paused) 영상 시간은 계속 센다 — 맵은 PromoFights가 PAUSABLE로 되돌린다
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_words()
	_fights = FIGHTS.new()
	add_child(_fights)

func _build_words() -> void:
	# 앞부분 자막과 같은 바탕체 + 검은 윤곽선(2026-10-13 사용자)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Batang", "바탕"])
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_words = Control.new()
	_words.set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_words)
	_w1 = _make_word(word_1, font)
	_w2 = _make_word(word_2, font)
	_words.add_child(_w1)
	_words.add_child(_w2)
	# 장면이 바뀌는 순간 하얗게 번쩍
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	# 로고(맨 끝)
	_logo_layer = CanvasLayer.new()
	_logo_layer.layer = 70
	_logo_layer.visible = false
	add_child(_logo_layer)
	var logo_bg := ColorRect.new()
	logo_bg.color = Color.BLACK
	logo_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_layer.add_child(logo_bg)
	_logo = load("res://ui/TitleLogo.tscn").instantiate()
	_logo_layer.add_child(_logo)

func _make_word(text: String, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", word_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	return l

func _process(delta: float) -> void:
	# 카운터 슬로(Engine.time_scale)와 상관없이 영상 시간으로 센다
	_t += minf(delta, 0.05) / maxf(Engine.time_scale, 0.01)
	_update_words()
	# 싸우는 장면 — 글자 화면이 끝나면 2초마다 다음 판
	var fights_start: float = t_words_end
	# 판마다 길이가 다르다(기본 2초, 운동 2.2초, 궁극기 6.8초)
	var fights_end: float = fights_start
	var i: int = -1
	for k in _fights.count():
		if _t >= fights_end:
			i = k
		fights_end += _fights.length_of(k)
	if _t >= fights_start and _t < fights_end:
		if i != _fight_index:
			_fight_index = i
			_black.visible = false
			_words.visible = false
			_flash.color.a = 0.85
			_fights.play(i)
	_flash.color.a = maxf(_flash.color.a - delta * 6.0, 0.0)
	# 로고
	if _once("logo", fights_end):
		_fights.stop()
		_logo_layer.visible = true
		_flash.color.a = 1.0
	if _logo_layer.visible:
		var k: float = _ease_out_back(clampf((_t - fights_end) / 0.45, 0.0, 1.0))
		var view: Vector2 = get_viewport().get_visible_rect().size
		var base: Vector2 = _logo.custom_minimum_size
		var s: float = logo_scale * lerpf(0.6, 1.0, k)
		_logo.scale = Vector2(s, s)
		_logo.position = view * 0.5 - base * s * 0.5
		_logo.modulate.a = clampf((_t - fights_end) / 0.25, 0.0, 1.0)
	_snapshot()
	if _t >= fights_end + logo_len:
		get_tree().quit()

## "그들이"는 커졌다가 딱 자리 잡고, "격돌합니다"는 오른쪽 밖에서 날아와 옆에 부딪힌다
func _update_words() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var gap: float = 36.0
	var w1: Vector2 = _w1.get_minimum_size()
	var w2: Vector2 = _w2.get_minimum_size()
	var total: float = w1.x + gap + w2.x
	var left: float = (view.x - total) * 0.5
	var y: float = (view.y - w1.y) * 0.5
	# 부딪힌 뒤 둘이 같이 밀렸다 돌아오는 흔들림
	var shake: Vector2 = Vector2.ZERO
	if _t >= t_word_2_hit:
		var a: float = maxf(0.0, 1.0 - (_t - t_word_2_hit) / 0.35)
		shake = Vector2(sin((_t - t_word_2_hit) * 70.0) * 14.0, cos((_t - t_word_2_hit) * 55.0) * 6.0) * a
	# 그들이
	var p1: float = clampf((_t - t_word_1) / 0.12, 0.0, 1.0)
	_w1.modulate.a = p1
	_w1.pivot_offset = w1 * 0.5
	_w1.scale = Vector2.ONE * lerpf(1.6, 1.0, _ease_out(p1))
	var push: float = 0.0
	if _t >= t_word_2_hit:
		push = -18.0 * maxf(0.0, 1.0 - (_t - t_word_2_hit) / 0.18)
	_w1.position = Vector2(left, y) + shake + Vector2(push, 0)
	# 격돌합니다
	var p2: float = clampf((_t - t_word_2_start) / maxf(t_word_2_hit - t_word_2_start, 0.01), 0.0, 1.0)
	_w2.modulate.a = 1.0 if _t >= t_word_2_start else 0.0
	var target_x: float = left + w1.x + gap
	_w2.position = Vector2(lerpf(view.x + 40.0, target_x, p2 * p2), y) + shake
	# 부딪히는 순간 번쩍
	if _once("hit_flash", t_word_2_hit):
		_flash.color.a = 0.55

func _snapshot() -> void:
	var frame: int = roundi(_t * 60.0)
	var shots: String = _arg("shots")
	var dense: float = float(_arg("dense")) if _arg("dense") != "" else -1.0
	var dense_now: bool = dense >= 0.0 and _t >= dense and _t < dense + 0.5 and frame % 3 == 0
	if shots != "" and (frame % 30 == 0 or dense_now):
		get_viewport().get_texture().get_image().save_png("%s/t%05.2f.png" % [shots, _t])

func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""

func _once(key: String, at: float) -> bool:
	if _done.has(key) or _t < at:
		return false
	_done[key] = true
	return true

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_out_back(x: float) -> float:
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)
