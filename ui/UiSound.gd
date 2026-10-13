extends Node
## 메뉴·UI 클릭 소리를 한 곳에서 낸다(오토로드 `UiSound`).
##
## - **버튼(BaseButton)** 은 트리에 들어오는 순간 `pressed`에 소리를 붙인다 — 화면마다 따로 넣을 필요 없다
## - **키보드 메뉴 조작**(ui_accept·ui_cancel·화살표)은 메뉴 화면이거나 일시정지 창이 떠 있을 때만 낸다.
##   전투 중엔 P2 이동키가 화살표라서 그때 울리면 안 된다
## - 소리를 빼고 싶은 버튼은 `set_meta("no_click_sound", true)`
## - 타이틀 화면은 자기 클릭 소리(`TitleScreen/Click`)가 따로 있어서 키보드 쪽은 건너뛴다

const CLICK_PATH := "res://audio/click.mp3"
## 한 번 누를 때 키 입력 + 버튼 pressed가 같이 오면 두 번 울린다 — 이 시간 안의 두 번째는 버린다
const DEDUPE_MSEC := 60
const MENU_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]

var _player: AudioStreamPlayer
var _last_play_msec: int = -100000
## 지금 떠 있는 일시정지 창(없으면 null) — 전투 중에도 이게 있으면 메뉴로 친다
var _pause_menu: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Sfx"
	if ResourceLoader.exists(CLICK_PATH):
		_player.stream = load(CLICK_PATH)
		_player.volume_db = Sfx.gain_of(_player.stream)   # 크기는 Sfx 표에서
	else:
		push_warning("UiSound: 클릭 소리 파일이 없다 — %s" % CLICK_PATH)
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)

## 클릭 소리 한 번
func play_click() -> void:
	if _player.stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_play_msec < DEDUPE_MSEC:
		return
	_last_play_msec = now
	_player.play()

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed.bind(button))
	elif node is TabBar:
		var tabs: TabBar = node
		if not tabs.tab_clicked.is_connected(_on_tab_clicked):
			tabs.tab_clicked.connect(_on_tab_clicked)
	elif node is PauseMenu:
		_pause_menu = node
		play_click()   # 일시정지 창이 열리는 것도 메뉴 조작이다(ESC로 열 때)

func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and button.has_meta("no_click_sound"):
		return
	play_click()

func _on_tab_clicked(_tab: int) -> void:
	play_click()

func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if not _in_menu():
		return
	for action in MENU_ACTIONS:
		if event.is_action_pressed(action):
			play_click()
			return

## 키보드 메뉴 조작에 소리를 낼 때인가 — 일시정지 창이 떠 있거나, 지금 씬이 메뉴 화면(Control)일 때
func _in_menu() -> bool:
	if is_instance_valid(_pause_menu) and _pause_menu.is_inside_tree():
		return true
	var scene: Node = get_tree().current_scene
	if scene == null or not (scene is Control):
		return false   # 전투(Stage)·튜토리얼 맵
	if scene is TitleScreen or scene is StoryFadeScene:
		return false   # 타이틀은 자기 소리가 있고, 스토리는 대사 넘기기라 메뉴가 아니다
	return true
