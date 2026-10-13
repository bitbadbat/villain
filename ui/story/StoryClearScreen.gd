extends Control

## **에피소드 클리어 화면**(2026-10-13 사용자: "클리어하면 에피소드1 잼민이 클리어 이런 식으로
## 띄워 주고 다음 에피소드·메인메뉴 두 가지 나오게"). 이야기의 마지막 장면이
## 검게 덮인 뒤 이 화면으로 넘어온다 — 그래서 **검은 화면에서 스스로 밝아진다**.
##
## 어느 에피소드를 깼는지는 `GameState.current_story_id`로 안다. 이름은 "EP.1-첫 임무"처럼
## 앞뒤가 `-`로 나뉘어 있어서, 앞은 크게(EP.1 클리어) 뒤는 작게(첫 임무) 쓴다.
##
## **다음 에피소드 버튼은 다음 자리가 비어 있으면 안 보인다** — 아직 안 만든 이야기로
## 넘어가면 아무 일도 안 일어나서, 누를 수 있게 두면 고장 난 것처럼 보인다

const MAIN_MENU := "res://ui/MainMenu.tscn"
const FONT := "res://fonts/Jua-Regular.ttf"
const INK := Color(0.06, 0.05, 0.08)

## 검은 화면에서 밝아지는 시간(초)
@export var fade_in_time: float = 0.7
## 글자·버튼이 차례로 떠오르는 간격(초)과 하나가 떠오르는 시간(초)
@export var reveal_gap: float = 0.22
@export var reveal_time: float = 0.35
## 버튼 바탕 — 결과창과 같은 납작한 노랑
@export var button_color: Color = Color(1.0, 0.82, 0.18)
@export var background_color: Color = Color(0.07, 0.06, 0.11)

var _next_id: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var font: Font = load(FONT) if ResourceLoader.exists(FONT) else null

	var back := ColorRect.new()
	back.color = background_color
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	var episode: Dictionary = GameState.story_episode(GameState.current_story_id)
	var full_name: String = str(episode.get("name", ""))
	var head: String = full_name
	var tail: String = ""
	var dash: int = full_name.find("-")
	if dash > 0:
		head = full_name.substr(0, dash)
		tail = full_name.substr(dash + 1)

	var title := Label.new()
	# **큰 글씨는 에피소드 제목**("첫 임무 클리어"), 작은 글씨가 몇 화인지("EP.1")다(2026-10-13 사용자)
	title.text = "%s 클리어" % tail if tail != "" else "클리어"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_outline(title, 10)
	if font:
		title.add_theme_font_override("font", font)

	var subtitle := Label.new()
	subtitle.text = head
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.84, 0.92))
	_outline(subtitle, 6)
	if font:
		subtitle.add_theme_font_override("font", font)
	subtitle.visible = head != ""
	# 작은 "EP.1"이 위, 큰 "첫 임무 클리어"가 아래 — 몇 화인지 먼저 읽히고 제목이 눈에 박힌다
	box.add_child(subtitle)
	box.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 54)
	box.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	_next_id = _find_next_episode()
	var waves: Array[Control] = [subtitle, title]
	if _next_id != "":
		var next_button := _make_button("다음 에피소드", font)
		next_button.pressed.connect(_on_next_pressed)
		row.add_child(next_button)
		waves.append(next_button)
	var menu_button := _make_button("메인메뉴로", font)
	menu_button.pressed.connect(_on_menu_pressed)
	row.add_child(menu_button)
	waves.append(menu_button)

	# 검은 장막을 덮었다가 걷는다 — 앞 장면이 검게 끝나서 이어 붙듯 밝아진다
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 1)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var tw: Tween = create_tween()
	tw.tween_property(veil, "color:a", 0.0, fade_in_time)
	tw.tween_callback(veil.queue_free)

	_reveal(waves)

## 글자와 버튼을 차례로 띄운다 — 한꺼번에 나오면 밋밋하다.
## ⚠️ **자리는 건드리지 않는다.** 이 노드들은 VBoxContainer의 자식이라 자리를 컨테이너가 쥐고 있다 —
## `position`을 손대면 컨테이너가 도로 잡아 놓는 자리와 싸워서 글자가 겹친다(2026-10-13 실측)
func _reveal(nodes: Array[Control]) -> void:
	var delay: float = fade_in_time * 0.5
	for node in nodes:
		if not is_instance_valid(node) or not node.visible:
			continue
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, reveal_time).set_delay(delay)
		delay += reveal_gap

## 지금 에피소드 **다음 줄**부터 훑어 처음 만나는 "만들어 둔" 에피소드. 없으면 빈 문자열
func _find_next_episode() -> String:
	var found: bool = false
	for episode in GameState.STORY_EPISODES:
		if found and str(episode.get("scene", "")) != "":
			return str(episode.get("id", ""))
		if str(episode.get("id", "")) == GameState.current_story_id:
			found = true
	return ""

func _make_button(text: String, font: Font) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230.0, 62.0)
	button.add_theme_stylebox_override("normal", _box(button_color))
	button.add_theme_stylebox_override("hover", _box(button_color.lightened(0.25)))
	button.add_theme_stylebox_override("pressed", _box(button_color.darkened(0.18)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_font_size_override("font_size", 28)
	if font:
		button.add_theme_font_override("font", font)
	return button

func _box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	return box

func _outline(label: Label, width: int) -> void:
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", width)

func _on_next_pressed() -> void:
	if not GameState.start_story(_next_id):
		get_tree().change_scene_to_file(MAIN_MENU)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
