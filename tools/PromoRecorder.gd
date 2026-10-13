extends Node

## 홍보 영상 소스 녹화(2026-10-13). **AI 둘이 HUD·컷인·카운터 연출까지 다 켠 진짜 대전**을 띄우고
## 정해진 시간이 지나면 저절로 꺼진다. Godot Movie Maker로 돌려야 파일이 생긴다:
##   godot --path . --write-movie out.avi --fixed-fps 60 res://tools/PromoRecorder.tscn -- map=지하철역 p1=지하철 아저씨 p2=주정뱅이 sec=60
## 인자를 안 주면 아래 기본값. 라운드가 끝나 씬이 다시 읽혀도 녹화 시간은 이어서 센다(static)

const DEFAULT_ARGS := {"map": "지하철역", "p1": "지하철 아저씨", "p2": "주정뱅이", "sec": "60", "cd": "0.5"}

static var _started_frame: int = -1
static var _limit_frames: int = 0

func _ready() -> void:
	var args: Dictionary = DEFAULT_ARGS.duplicate()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if _started_frame < 0:
		_started_frame = Engine.get_process_frames()
		_limit_frames = int(float(args.sec) * 60.0)
		GameState.game_mode = "pvp"
		GameState.vs_ai = true
		GameState.p1_character_path = _character(args.p1)
		GameState.p2_character_path = _character(args.p2)
		GameState.selected_map_path = GameState.MAPS[args.map]
		GameState.cooldown_multiplier = float(args.cd)
		GameState.p1_round_wins = 0
		GameState.p2_round_wins = 0
	var map: Node = load(GameState.selected_map_path).instantiate()
	add_child(map)
	# P1도 AI로 — Stage는 P1에 사람 조작기를 붙이므로 한 프레임 뒤 갈아 끼운다
	await get_tree().process_frame
	for c in map.find_children("*", "PlayerController", true, false):
		var fighter: Node = c.get_parent()
		var active: bool = c.is_active
		c.queue_free()
		var ai := AIController.new()
		ai.is_active = active
		fighter.add_child(ai)

func _process(_delta: float) -> void:
	var f: int = Engine.get_process_frames() - _started_frame
	# shots=<폴더> 를 주면 4초마다 확인용 스냅샷을 남긴다
	var shots: String = _arg("shots")
	if shots != "" and f > 0 and f % 240 == 0:
		get_viewport().get_texture().get_image().save_png("%s/shot_%03d.png" % [shots, f / 60])
	if f >= _limit_frames:
		get_tree().quit()

func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""

func _character(char_name: String) -> String:
	if GameState.CHARACTERS.has(char_name):
		return GameState.CHARACTERS[char_name]
	return GameState.TRAINING_ONLY_CHARACTERS.get(char_name, GameState.CHARACTERS.values()[0])
