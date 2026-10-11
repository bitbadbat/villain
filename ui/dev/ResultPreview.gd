extends Node

## 개발자 모드 — **승패 연출 미리보기**(2026-10-11 사용자: "승리/패배 화면 볼려면 직접 게임을 플레이하고 나서야 확인이 가능하니까
## 개발 단계에서 편의성을 가질 수 있는 모드를 만들고 싶어").
## 게임을 안 하고도 승자·패자·맵·P1/P2·무승부를 골라 **게임과 같은 순서**(승리 → 패배 → 연행 → 결과 띠)를 바로 돌려 본다.
## - 들어오는 법: 메인 메뉴에서 **F1**(`MainMenu.debug_dev_key`), 또는 에디터에서 이 씬을 F6
## - 재생 중: R = 같은 설정으로 다시 / 1·2·3 = 전체·승리패배만·연행만 / Esc = 고르는 화면. 고르는 화면에서 Esc = 메인 메뉴
## - 연출에 넘기는 info는 `Stage._match_ending_info()`와 같은 약속이다 — 그쪽 키가 바뀌면 여기도 같이 고칠 것
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러)

const MATCH_ENDING_SCENE := "res://ui/result/MatchEnding.tscn"
const ARREST_SCENE := "res://ui/result/ArrestScene.tscn"
const ARREST_SCRIPT := "res://ui/result/ArrestScene.gd"
const RESULT_SCENE := "res://ui/MatchResult.tscn"
const MAIN_MENU := "res://ui/MainMenu.tscn"
const POLICE_RIG := "res://characters/police/PoliceRig.tscn"
const FONT := preload("res://fonts/Jua-Regular.ttf")
## 결과 띠는 연행 장면(layer 25) 위 — `Stage.RESULT_OVER_ENDING_LAYER`와 같은 값
const RESULT_LAYER := 30
## 고르는 화면·안내 글자는 모든 연출 위
const UI_LAYER := 60

enum Part { ALL, ENDING, ARREST }

## 고른 값 — 씬을 다시 불러도(결과 띠의 "다시 하기"는 지금 씬을 다시 부른다) 남는다
static var _winner: int = 0
static var _loser: int = 1
static var _map: int = 0
static var _p1_won: bool = true
static var _is_draw: bool = false
static var _with_result: bool = true

var _names: Array = []
var _rigs: Array = []
var _map_names: Array = []
var _map_paths: Array = []
var _picker: CanvasLayer
var _hint: CanvasLayer
var _hint_label: Label
var _winner_opt: OptionButton
var _loser_opt: OptionButton
var _map_opt: OptionButton
var _side_opt: OptionButton
var _draw_check: CheckBox
var _result_check: CheckBox
## 지금 떠 있는 연출 노드들 — Esc·R이면 다 치운다
var _shown: Array = []
## 재생 번호 — 중간에 끊고 다시 틀면 앞 재생이 await 뒤에서 이어 돌지 않게
var _run: int = 0
var _hint_time: float = 0.0
## R(다시)이 되풀이할 마지막 재생 범위
var _last_part: int = Part.ALL

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	for character_name in GameState.CHARACTER_RIGS:
		_names.append(character_name)
		_rigs.append(GameState.CHARACTER_RIGS[character_name])
	_names.append("주인공(경찰)")
	_rigs.append(POLICE_RIG)
	for map_name in GameState.MAPS:
		_map_names.append(map_name)
		_map_paths.append(GameState.MAPS[map_name])
	_map_names.append("(기본 경찰서)")
	_map_paths.append("")
	_build_picker()
	_build_hint()
	_show_picker()

func _process(delta: float) -> void:
	# 안내 글자는 재생이 시작되고 2.5초 뒤 흐려진다(연출을 가리지 않게)
	if _hint.visible:
		_hint_time += delta
		_hint_label.modulate.a = 1.0 if _hint_time < 2.5 else maxf(0.25, 1.0 - (_hint_time - 2.5) * 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if _picker.visible:
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file(MAIN_MENU)
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_play(Part.ALL)
		return
	match key:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_show_picker()
		KEY_R:
			get_viewport().set_input_as_handled()
			_play(_last_part)
		KEY_1:
			get_viewport().set_input_as_handled()
			_play(Part.ALL)
		KEY_2:
			get_viewport().set_input_as_handled()
			_play(Part.ENDING)
		KEY_3:
			get_viewport().set_input_as_handled()
			_play(Part.ARREST)

# ---------------------------------------------------------------- 재생

func _play(part: int) -> void:
	_read_picker()
	_clear()
	_last_part = part
	_run += 1
	var run: int = _run
	_picker.visible = false
	_hint.visible = true
	_hint_time = 0.0
	GameState.game_mode = "pvp"   # 결과 띠 글자("P1 ○○ 승리!")가 대전 기준이라
	var info: Dictionary = _info()
	var is_draw: bool = bool(info["is_draw"])
	var arrest_script = load(ARREST_SCRIPT)
	if part != Part.ARREST and not is_draw:
		var ending: Node = load(MATCH_ENDING_SCENE).instantiate()
		add_child(ending)
		_shown.append(ending)
		ending.play(info)
		# 게임처럼 승리 화면이 리그를 다 읽은 뒤에 연행 리그를 뒤에서 읽어 둔다
		if part == Part.ALL and arrest_script != null:
			arrest_script.warm_up([ARREST_SCENE, info["winner_rig"], info["loser_rig"]])
		await ending.finished
		if run != _run:
			return
		_shown.erase(ending)
		ending.queue_free()
	if part == Part.ENDING:
		return
	var arrest: Node = load(ARREST_SCENE).instantiate()
	add_child(arrest)
	_shown.append(arrest)
	arrest.play(info)
	await arrest.finished
	if run != _run or part != Part.ALL or not _with_result:
		return
	var result: MatchResult = load(RESULT_SCENE).instantiate()
	result.layer = RESULT_LAYER
	add_child(result)
	_shown.append(result)
	result.dock_bottom()
	if is_draw:
		result.show_draw()
	else:
		result.show_result(_p1_won, str(info["winner_name"]))

## 떠 있는 연출을 다 치운다(연행 장면이 미리 읽어 둔 리그도 놓는다)
func _clear() -> void:
	_run += 1
	for node in _shown:
		if is_instance_valid(node):
			node.queue_free()
	_shown.clear()
	var arrest_script = load(ARREST_SCRIPT)
	if arrest_script != null:
		arrest_script.release_warm()

## Stage._match_ending_info()와 같은 모양. 무승부면 P1을 승자 자리, P2를 패자 자리에 채운다
func _info() -> Dictionary:
	var winner_is_p1: bool = _p1_won or _is_draw
	var same: bool = _rigs[_winner] == _rigs[_loser]
	return {
		"winner_rig": _rigs[_winner], "loser_rig": _rigs[_loser],
		"winner_is_p1": winner_is_p1,
		"winner_name": _names[_winner], "loser_name": _names[_loser],
		"winner_p2_color": same and not winner_is_p1,
		"loser_p2_color": same and winner_is_p1,
		"is_draw": _is_draw,
		"map_path": _map_paths[_map],
	}

# ---------------------------------------------------------------- 고르는 화면

func _show_picker() -> void:
	_clear()
	_hint.visible = false
	_picker.visible = true
	_winner_opt.grab_focus()

func _read_picker() -> void:
	_winner = _winner_opt.selected
	_loser = _loser_opt.selected
	_map = _map_opt.selected
	_p1_won = _side_opt.selected == 0
	_is_draw = _draw_check.button_pressed
	_with_result = _result_check.button_pressed

func _randomize() -> void:
	_winner_opt.select(randi() % _names.size())
	_loser_opt.select(randi() % _names.size())
	_map_opt.select(randi() % (_map_names.size() - 1))
	_side_opt.select(randi() % 2)

func _build_picker() -> void:
	_picker = CanvasLayer.new()
	_picker.layer = UI_LAYER
	add_child(_picker)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 24
	root.theme = theme
	_picker.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.15, 0.24)
	box.border_color = Color(0.06, 0.05, 0.08)
	box.set_border_width_all(4)
	box.set_corner_radius_all(16)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 26
	box.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := Label.new()
	title.text = "개발자 모드 — 승패 연출 미리보기"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	_winner_opt = _option(grid, "승자", _names, _winner)
	_loser_opt = _option(grid, "패자", _names, _loser)
	_map_opt = _option(grid, "맵(연행 배경)", _map_names, _map)
	_side_opt = _option(grid, "이긴 쪽", ["P1 (왼쪽)", "P2 (오른쪽)"], 0 if _p1_won else 1)
	_draw_check = _check(grid, "무승부(연행만, 둘 다 끌려감)", _is_draw)
	_result_check = _check(grid, "끝나고 결과 띠", _with_result)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	_button(buttons, "전체 재생", func() -> void: _play(Part.ALL))
	_button(buttons, "승리·패배만", func() -> void: _play(Part.ENDING))
	_button(buttons, "연행만", func() -> void: _play(Part.ARREST))
	_button(buttons, "무작위", _randomize)
	var help := Label.new()
	help.text = "Enter = 전체 재생   |   재생 중  R 다시 · 1 전체 · 2 승리/패배 · 3 연행 · Esc 돌아오기   |   여기서 Esc = 메인 메뉴"
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)

func _option(parent: Control, label_text: String, items: Array, selected: int) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(320, 0)
	for item in items:
		opt.add_item(str(item))
	opt.select(clampi(selected, 0, items.size() - 1))
	parent.add_child(opt)
	return opt

func _check(parent: Control, label_text: String, on: bool) -> CheckBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var check := CheckBox.new()
	check.button_pressed = on
	parent.add_child(check)
	return check

func _button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.pressed.connect(action)
	parent.add_child(b)

func _build_hint() -> void:
	_hint = CanvasLayer.new()
	_hint.layer = UI_LAYER
	add_child(_hint)
	_hint_label = Label.new()
	_hint_label.text = "개발자 미리보기   R 다시 · 1 전체 · 2 승리/패배 · 3 연행 · Esc 돌아오기"
	_hint_label.add_theme_font_override("font", FONT)
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.position = Vector2(14, 10)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_hint_label)
	_hint.visible = false
