class_name DamagePopup
extends Node2D

## 피격 지점에 데미지 숫자를 통통 튀며 위로 띄웠다 사라지게 하는 팝업. 콤보 2 이상이면 "N HIT"도 같이 표시한다.
## Hitbox가 명중 지점에서 스폰하고 setup(데미지, 콤보)로 값을 넘긴다.

## 이 데미지 이상이면 숫자가 가장 크고 빨갛게 표시된다 (그 미만은 데미지에 비례해 작고 흰색 쪽)
@export var big_hit_damage: float = 25.0
## 방어로 막았을 때 뜨는 "BLOCK" 글자 크기·색 (데미지 숫자와 달리 세기에 안 비례한다)
@export var block_font_size: int = 28
@export var block_color: Color = Color(0.55, 0.8, 1.0)
## 떠오르는 높이(px)와 전체 지속시간(초)
@export var rise_height: float = 34.0
@export var duration: float = 0.6
## 데미지 아이콘(`데미지 아이콘.png` 톱니 말풍선) 화면 크기(px) — 약타 / 강타(big_hit_damage 이상) 사이로 커진다
@export var icon_size_min: float = 54.0
@export var icon_size_max: float = 92.0
## 숫자 색 — 아이콘 안쪽 흰 공백에 검은 숫자(2026-10-11 사용자)
@export var number_color: Color = Color(0.05, 0.04, 0.04)
## 콤보 아이콘(`콤보.png` "COMBO" 말풍선) 화면 폭(px) — 데미지 아이콘 위에 뜬다
@export var combo_icon_width: float = 130.0

## 아이콘 안쪽 흰 공백의 지름이 그림 폭의 몇 배인지(2026-10-11 실측: 1254px 그림에서 반경 507~544) — 그림을 바꾸면 다시 잴 것
const ICON_INNER_RATIO: float = 0.8
## 숫자 폰트 = 게임 공용 주아체(기호 글리프는 없지만 숫자는 있다)
const NUMBER_FONT: Font = preload("res://fonts/Jua-Regular.ttf")
## 콤보 아이콘(1774x887)의 보이는 말풍선 폭과, "COMBO" 글자 오른쪽 빈 칸(가운데·크기, 그림 가운데 기준 px).
## 2026-10-11 실측: 말풍선 x 324~1448, 빈 칸 x 1158~1390 / y 319~584 — 그림을 바꾸면 다시 잴 것
const COMBO_BUBBLE_WIDTH: float = 1124.0
const COMBO_SLOT_CENTER := Vector2(387.0, 8.0)
const COMBO_SLOT_SIZE := Vector2(232.0, 265.0)

@onready var _damage: Label = $Damage
@onready var _combo: Label = $Combo
@onready var _icon: Sprite2D = $Icon
@onready var _combo_icon: Sprite2D = $ComboIcon
@onready var _combo_number: Label = $ComboNumber

## 데미지 숫자와(콤보 2 이상이면) 콤보 수를 설정하고 애니메이션을 시작한다
func setup(damage: int, combo: int = 0) -> void:
	z_index = 100   # 캐릭터·이펙트 위에 그린다
	_combo.add_theme_constant_override("outline_size", 6)
	_combo.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	# 톱니 아이콘 안쪽 흰 공백에 검은 숫자 — 세게 맞을수록 아이콘이 커진다
	var t: float = clampf(float(damage) / big_hit_damage, 0.0, 1.0)
	var icon_px: float = lerpf(icon_size_min, icon_size_max, t)
	_icon.visible = true
	_icon.scale = Vector2.ONE * icon_px / maxf(_icon.texture.get_width(), 1.0)
	_damage.text = str(damage)
	_damage.add_theme_font_override("font", NUMBER_FONT)
	_damage.add_theme_color_override("font_color", number_color)
	_damage.add_theme_constant_override("outline_size", 0)
	# 숫자가 안쪽 공백을 안 넘게 — 높이는 공백의 60%, 자릿수가 많으면 폭에 맞춰 줄인다(주아체 숫자 폭 ≈ 글자 크기 x 0.55)
	var inner: float = icon_px * ICON_INNER_RATIO
	var digits: int = _damage.text.length()
	var font_px: float = minf(inner * 0.6, inner * 0.85 / (0.55 * digits))
	_damage.add_theme_font_size_override("font_size", int(round(font_px)))
	# 콤보는 "COMBO" 말풍선 아이콘을 데미지 아이콘 위에 띄우고, 글자 오른쪽 빈 칸에 검은 숫자(2026-10-11 사용자)
	_combo.visible = false
	_combo_icon.visible = combo >= 2
	_combo_number.visible = combo >= 2
	if combo >= 2:
		var s: float = combo_icon_width / COMBO_BUBBLE_WIDTH
		_combo_icon.scale = Vector2(s, s)
		_combo_icon.position = Vector2(0.0, -icon_px * 0.5 - 620.0 * s * 0.5 + 4.0)
		_combo_number.text = str(combo)
		_combo_number.add_theme_font_override("font", NUMBER_FONT)
		_combo_number.add_theme_color_override("font_color", number_color)
		var slot: Vector2 = COMBO_SLOT_SIZE * s
		var combo_px: float = minf(slot.y * 0.9, slot.x * 1.0 / (0.55 * _combo_number.text.length()))
		_combo_number.add_theme_font_size_override("font_size", int(round(combo_px)))
		# 라벨 상자 가운데를 빈 칸 가운데에
		_combo_number.size = Vector2(300, 300)
		_combo_number.position = _combo_icon.position + COMBO_SLOT_CENTER * s - _combo_number.size * 0.5

	_animate()

## 콤보 말풍선만 띄운다(가운데 = 내 원점) — 대전 HUD가 콤보는 때린 쪽 판, 데미지는 맞은 쪽 판에 따로 띄울 때 쓴다
func setup_combo(combo: int) -> void:
	z_index = 100
	_icon.visible = false
	_damage.visible = false
	_combo.visible = false
	_combo_icon.visible = true
	_combo_number.visible = true
	var s: float = combo_icon_width / COMBO_BUBBLE_WIDTH
	_combo_icon.scale = Vector2(s, s)
	_combo_icon.position = Vector2.ZERO
	_combo_number.text = str(combo)
	_combo_number.add_theme_font_override("font", NUMBER_FONT)
	_combo_number.add_theme_color_override("font_color", number_color)
	var slot: Vector2 = COMBO_SLOT_SIZE * s
	var combo_px: float = minf(slot.y * 0.9, slot.x * 1.0 / (0.55 * _combo_number.text.length()))
	_combo_number.add_theme_font_size_override("font_size", int(round(combo_px)))
	_combo_number.size = Vector2(300, 300)
	_combo_number.position = COMBO_SLOT_CENTER * s - _combo_number.size * 0.5
	_animate()

## 방어로 막혔을 때 — 숫자 대신 "BLOCK"을 띄운다. 실제로 깎인 HP가 0이라 숫자를 띄우면
## 막았는데도 데미지가 들어간 것처럼 보인다. 크기·색은 데미지와 무관하게 고정이다
func setup_block() -> void:
	z_index = 100
	# 막았을 땐 데미지 아이콘 없이 글자만
	_icon.visible = false
	_combo_icon.visible = false
	_combo_number.visible = false
	for lbl in [_damage, _combo]:
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_damage.text = "BLOCK"
	_damage.add_theme_font_size_override("font_size", block_font_size)
	_damage.add_theme_color_override("font_color", block_color)
	_combo.visible = false
	_animate()

func _animate() -> void:
	# 살짝 작게 시작해 통통 튀어오르며 커진다
	scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	# 위로 떠오른다
	var up := create_tween()
	up.tween_property(self, "position:y", position.y - rise_height, duration).set_ease(Tween.EASE_OUT)
	# 뒷부분에 서서히 사라지고 정리
	var fade := create_tween()
	fade.tween_interval(duration * 0.55)
	fade.tween_property(self, "modulate:a", 0.0, duration * 0.45)
	fade.tween_callback(queue_free)
