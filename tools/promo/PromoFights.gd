extends Node

## 홍보 영상 "격돌" 장면들(2026-10-13) — `PromoOutro`가 2초마다 play(i)를 부른다.
## 카운터 연출(CounterHitFx)·타격음·데미지 숫자가 나오게 **구경 모드가 아닌 대전 모드**로 맵을 띄우고,
## 팝업 인트로·일시정지 버튼은 add_child 전에 끄고, 카운트다운은 뜨자마자 끝낸다. HUD·쿨타임 원은 숨긴다.
##
## ⚠️ 원래 조종기(PlayerController/AIController)는 떼고 **대본 조종기 `Pilot`** 을 단다 — P1 조종기는 키보드를
## 그대로 읽어서, 녹화 중에 키를 누르면 캐릭터가 움직이거나 ESC로 일시정지 메뉴가 떴다(2026-10-13 실제로 겪음).
## Pilot이 조종기 대신 매 프레임 move + apply_physics를 돌린다(이걸 안 돌리면 캐릭터가 얼어붙는다).
## 맵의 키 입력(_input/_unhandled_input)도 끈다.
##
## 대본 한 줄 = [시각, 누가(1/2), 동작, 값]
##   "approach" 값=간격 — 상대 쪽으로 달려가 그 간격에서 멈추고 마주 본다
##   "move" 값=방향(-1/1) / "stop" / "jump"
##   "basic" / "skill_1" / "skill_2" — 바로 누름(쿨은 비워 줌)
##   "hit_close" — 붙을 때까지 기다렸다가 평타 한 번
##   "combo" 값=끝 시각 — 그때까지 붙어 있으면 평타를 계속 눌러 1→2→3타
##   "ultimate" — 궁극기(컷인 → 발동). 컷인 동안 트리가 멈추므로 영상 시간은 PromoOutro(ALWAYS)가 센다
##   "workout" — 가까운 기구에서 운동 시작(맵 스킬)
## 판 키: "len" 길이(기본 2초) / "solo" 상대를 숨기고 혼자 / "machine" 그 기구 위에 세우고 "machine_rate"로 스택이 빨리 오르게
## "zoom" 이 판만 배율 더 곱하기 / "cam_dy" 땅 한계를 넘어 카메라를 이만큼 더 내리기(발이 잘릴 때)

var FIGHTS: Array = [
	# 1) 놀이터 — 금쪽이가 점프하며 달려들어 평타 3타 콤보로 일진 날리기. 일진도 맞서 달려온다
	{"map": "놀이터", "p1": "금쪽이", "p2": "일진", "x1": -620.0, "x2": -250.0, "surface": 280.0, "ground": 280.0,
		"events": [[0.0, 1, "approach", 48.0], [0.05, 1, "jump"], [0.1, 2, "approach", 48.0], [0.2, 1, "combo", 1.8]]},
	# 2) 번화가 — 둘이 달려와 붙고, 악플러가 휘두르기 시작한 순간 주정뱅이가 먼저 맞혀 카운터 → 이어서 콤보
	{"map": "번화가", "p1": "주정뱅이", "p2": "악플러", "x1": -470.0, "x2": -140.0, "surface": 286.0, "ground": 286.0,
		"events": [[0.0, 1, "approach", 55.0], [0.0, 2, "approach", 55.0], [0.55, 1, "basic"], [0.60, 2, "basic"], [0.8, 1, "combo", 1.8]]},
	# 3) 지하철 — 금쪽이가 비비탄을 쏘고, 아저씨가 점프로 피하며 다가가는데 열차가 들이닥쳐 둘을 휩쓴다
	{"map": "지하철역", "p1": "지하철 아저씨", "p2": "금쪽이", "x1": -300.0, "x2": -40.0, "surface": 300.0, "ground": 300.0,
		"train": true, "events": [[0.1, 2, "skill_2"], [0.15, 1, "move", 1.0], [0.2, 1, "jump"], [0.45, 1, "jump"], [0.75, 1, "stop"]]},
	# 3.5) 헬스장 운동 — 주정뱅이가 런닝머신을 달리며 발이 자전거 바퀴 → 스포츠카 바퀴 → 로켓 신발로 바뀐다
	#      (스택 4/7/10에서 바뀐다 — 초당 6이면 약 0.7/1.2/1.7초)
	{"map": "헬스장", "p1": "주정뱅이", "p2": "일진", "solo": true, "machine": "Equipment/Treadmill", "machine_rate": 6.0, "len": 2.2, "zoom": 1.25, "cam_dy": 110.0,
		"x1": 0.0, "x2": 0.0, "surface": 280.0, "ground": 280.0, "events": [[0.1, 1, "workout"]]},
	# 4) 헬스장 — 주정뱅이가 점프하며 다가오다 일진 담배 연기에 날아간다
	#    ⚠️ 헬스장은 좌표가 달라 1층 바닥이 y 621(2층 301)이다
	{"map": "헬스장", "p1": "일진", "p2": "주정뱅이", "x1": 640.0, "x2": 900.0, "surface": 621.0, "ground": 621.0,
		"events": [[0.0, 2, "approach", 120.0], [0.08, 2, "jump"], [0.3, 1, "skill_1"]]},
	# 5) 악플러의 집 — 악플러가 점프하며 덤비고, 지하철 아저씨 단소 반격 자세에 걸려 등 뒤에서 베인다
	{"map": "악플러의 집", "p1": "지하철 아저씨", "p2": "악플러", "x1": -250.0, "x2": -440.0, "face1": -1, "face2": 1, "surface": 280.0, "ground": 280.0,
		"events": [[0.0, 2, "approach", 55.0], [0.05, 2, "jump"], [0.3, 1, "skill_2"], [0.4, 2, "hit_close"]]},
	# 6) 지하철역 — 둘이 서로 궁극기. 컷인은 원래 4.8초/3.8초인데 **앞 3.4초만** 보여 주고 다음으로 넘어간다(2026-10-13 사용자)
	{"map": "지하철역", "p1": "지하철 아저씨", "p2": "고양이 아주머니", "x1": -200.0, "x2": 60.0, "surface": 300.0, "ground": 300.0, "len": 3.4,
		"events": [[0.0, 1, "ultimate"]]},
	{"map": "지하철역", "p1": "지하철 아저씨", "p2": "고양이 아주머니", "x1": -200.0, "x2": 60.0, "surface": 300.0, "ground": 300.0, "len": 3.4,
		"events": [[0.0, 2, "ultimate"]]},
]
## 맵 카메라 배율에 곱할 값 / 화면 가운데를 두 사람 가운데에서 얼마나 옮길지
@export var zoom_mult: float = 2.0
@export var cam_offset: Vector2 = Vector2(0, -50)
## 판 동안 아주 천천히 다가가는 정도(끝날 때 배율 x 이 값)
@export var push_in: float = 1.06
## 카메라가 두 사람 가운데를 따라가는 빠르기(1/초)
@export var cam_follow: float = 4.0
@export var hp_multiplier: float = 20.0

## 대본 조종기 — 조종기 대신 매 프레임 이동·물리를 돌린다. 키보드는 안 읽는다
class Pilot extends Node:
	var fighter: Fighter
	var target: Fighter
	var dir: float = 0.0
	var approach_gap: float = -1.0
	var combo_until: float = -1.0
	var hit_close: bool = false
	var clock: Callable

	func _physics_process(delta: float) -> void:
		if fighter == null or not is_instance_valid(fighter):
			return
		var gap_now: float = INF
		if target and is_instance_valid(target):
			gap_now = absf(target.global_position.x - fighter.global_position.x)
		if approach_gap > 0.0 and target:
			var d: float = target.global_position.x - fighter.global_position.x
			if absf(d) > approach_gap:
				dir = signf(d)
			else:
				dir = 0.0
				approach_gap = -1.0
				fighter.facing = int(signf(d)) if d != 0.0 else fighter.facing
		fighter.move(dir)
		fighter.apply_physics(delta)
		var now: float = clock.call()
		var close: bool = gap_now < 75.0 and fighter.is_on_floor()
		if combo_until > 0.0 and now <= combo_until and close:
			fighter.use_basic_attack()
		if hit_close and close:
			hit_close = false
			fighter.use_basic_attack()

var _map: Node
var _p1: Fighter
var _p2: Fighter
var _pilots: Dictionary = {}
var _fight: Dictionary = {}
var _t: float = 0.0
var _fired: Dictionary = {}
var _cam: Camera2D
var _cam_zoom: Vector2 = Vector2.ONE
var _cam_pos: Vector2 = Vector2.ZERO
var _ground_frac: float = 1.0
var _ready_to_drive: bool = false

func count() -> int:
	return FIGHTS.size()

## i번째 판의 길이(초)
func length_of(i: int) -> float:
	return float(FIGHTS[i].get("len", 2.0))

func play(i: int) -> void:
	_fight = FIGHTS[i]
	_t = 0.0
	_fired.clear()
	_ready_to_drive = false
	_cam = null
	# 앞 판이 궁극기 컷인 도중에 끝났으면 트리가 멈춘 채다 — 풀고 시작한다
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameState.game_mode = "pvp"
	GameState.vs_ai = true
	GameState.time_limit_seconds = 0
	GameState.hp_multiplier = hp_multiplier
	GameState.clash_minigame_enabled = false
	GameState.ultimate_cutin_enabled = true
	GameState.p1_round_wins = 0
	GameState.p2_round_wins = 0
	GameState.p1_character_path = GameState.CHARACTERS[_fight.p1]
	GameState.p2_character_path = GameState.CHARACTERS[_fight.p2]
	if _map:
		_map.queue_free()
	_p1 = null
	_p2 = null
	_pilots.clear()
	_map = load(GameState.MAPS[_fight.map]).instantiate()
	# 팝업북 인트로·일시정지 버튼은 add_child 전에 끈다
	_map.set("popup_intro_enabled", false)
	_map.set("pause_button", false)
	# 이 노드는 컷인이 트리를 멈춰도 시간을 세려고 ALWAYS다 — 맵은 원래대로 멈춰야 하므로 되돌린다
	_map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_map)
	# 키 입력을 안 받게(ESC 일시정지·디버그 키)
	_map.set_process_input(false)
	_map.set_process_unhandled_input(false)
	# Stage._ready는 첫 await 전에 두 캐릭터를 세운다
	_p1 = _map.get("_p1")
	_p2 = _map.get("_p2")
	_place(_p1, _fight.x1, int(_fight.get("face1", 1)))
	_place(_p2, _fight.x2, int(_fight.get("face2", -1)))
	_put_on_machine(_p1)
	if _fight.get("solo", false):
		_p2.visible = false
		_p2.process_mode = Node.PROCESS_MODE_DISABLED
		_p2.global_position = _p1.global_position + Vector2(-3000, 0)
	_attach_pilot(_p1, _p2, 1)
	_attach_pilot(_p2, _p1, 2)
	_freeze_map_gimmicks()
	await get_tree().process_frame
	if not is_instance_valid(_map):
		return
	_take_camera()
	if _fight.get("train", false):
		_start_train()
	_ready_to_drive = true

func stop() -> void:
	get_tree().paused = false
	if _map:
		_map.queue_free()
		_map = null
	Engine.time_scale = 1.0

## 원래 조종기를 떼고 대본 조종기를 단다
func _attach_pilot(f: Fighter, other: Fighter, who: int) -> void:
	if f == null:
		return
	for c in f.get_children():
		if c is AIController or c is PlayerController:
			f.remove_child(c)
			c.queue_free()
	var p := Pilot.new()
	p.fighter = f
	p.target = other
	p.clock = func() -> float: return _t
	f.add_child(p)
	_pilots[who] = p

## 발바닥을 딛는 면에 딱 붙여 세운다(위에서 떨어뜨리면 착지 효과가 보인다)
func _place(f: Fighter, x: float, face: int) -> void:
	if f == null:
		return
	f.velocity = Vector2.ZERO
	f.facing = face
	var feet: float = 30.0
	for c in f.get_children():
		if c is CollisionShape2D and c.shape:
			feet = c.position.y + c.shape.get_rect().end.y
			break
	f.global_position = Vector2(x, float(_fight.surface) - feet)

## 택시·쓰레기통·정전·엄마가 끼어들지 않게
func _freeze_map_gimmicks() -> void:
	for node_name in ["Taxi", "TrashCans", "Blackout", "MomDoorGimmick"]:
		var n: Node = _map.get_node_or_null(node_name)
		if n:
			n.process_mode = Node.PROCESS_MODE_DISABLED

func _take_camera() -> void:
	_cam = get_viewport().get_camera_2d()
	if _cam == null:
		return
	var view_h0: float = get_viewport().get_visible_rect().size.y / _cam.zoom.y
	var top0: float = _cam.get_screen_center_position().y - view_h0 * 0.5
	_ground_frac = clampf((float(_fight.ground) - top0) / view_h0, 0.0, 1.0)
	_cam_zoom = _cam.zoom * zoom_mult * float(_fight.get("zoom", 1.0))
	_cam.set_process(false)
	_cam.set_physics_process(false)
	_cam.position_smoothing_enabled = false
	_cam.drag_horizontal_enabled = false
	_cam.drag_vertical_enabled = false
	for side in ["limit_left", "limit_top"]:
		_cam.set(side, -100000)
	for side in ["limit_right", "limit_bottom"]:
		_cam.set(side, 100000)
	_cam_pos = _mid_point()

func _mid_point() -> Vector2:
	if _fight.get("solo", false):
		return _p1.global_position + cam_offset
	return (_p1.global_position + _p2.global_position) * 0.5 + cam_offset

## "machine"이 있으면 그 기구 한가운데 바닥에 발을 붙여 세우고, 스택이 빨리 오르게 한다
## (헬스장 기구 배치는 판마다 무작위라 자리를 표에 못 적는다)
func _put_on_machine(f: Fighter) -> void:
	var path: String = _fight.get("machine", "")
	if path == "" or f == null:
		return
	var m: Node2D = _map.get_node_or_null(path)
	if m == null:
		return
	m.set("spec_per_second", float(_fight.get("machine_rate", 1.0)))
	# 기구가 선 층의 바닥 = 헬스장 층 높이(1층 621 / 2층 301) 중 기구 원점에서 가장 가까운 것.
	# ⚠️ 기구 그림의 묻힌 깊이(sink)로 빼면 14px 떠서, 땅에 안 닿은 채 운동을 눌러 바로 끊겼다
	var floor_y: float = 621.0
	for level in [621.0, 301.0]:
		if absf(m.global_position.y - level) < absf(m.global_position.y - floor_y):
			floor_y = level
	_fight["surface"] = floor_y
	_fight["ground"] = floor_y
	_place(f, m.global_position.x, -1)

## 지하철 열차를 지금 바로 출발시키되, 2초 안에 두 사람에게 닿도록 가까이서 출발시킨다
func _start_train() -> void:
	var train: Node = _map.get_node_or_null("DecoSubwayTrain")
	if train == null:
		return
	train.set("min_cars", 2)
	train.set("max_cars", 2)
	train.set("_direction", 1)
	train.call("_begin_run")
	var body: Node2D = train.get("body")
	if body:
		body.position.x = float(_fight.get("train_start_x", -1100.0))

func _process(delta: float) -> void:
	if _map == null or not is_instance_valid(_map):
		return
	# 카운터 슬로(Engine.time_scale)와 상관없이 영상 시간으로 센다
	var real_dt: float = minf(delta, 0.05) / maxf(Engine.time_scale, 0.01)
	_t += real_dt
	_tidy_stage()
	if _cam and is_instance_valid(_cam) and _p1 and _p2 and is_instance_valid(_p1) and is_instance_valid(_p2):
		var z: Vector2 = _cam_zoom * lerpf(1.0, push_in, clampf(_t / 2.0, 0.0, 1.0))
		_cam.zoom = z
		# 둘이 움직이니 가운데를 부드럽게 따라간다(날아간 쪽까지 쫓지 않게 가로만 살짝)
		var want: Vector2 = _mid_point()
		_cam_pos.x = lerpf(_cam_pos.x, want.x, clampf(cam_follow * real_dt, 0.0, 1.0))
		var view_h: float = get_viewport().get_visible_rect().size.y / z.y
		var c: Vector2 = _cam_pos
		c.y = minf(c.y, float(_fight.ground) - (_ground_frac - 0.5) * view_h) + float(_fight.get("cam_dy", 0.0))
		_cam.global_position = c
	if not _ready_to_drive:
		return
	for i in _fight.events.size():
		var e: Array = _fight.events[i]
		if not _fired.has(i) and _t >= e[0]:
			_fired[i] = true
			_do(e[1], e[2], e[3] if e.size() > 3 else null)

## 카운트다운 끝내기 · HUD/쿨타임 원 숨기기 · 혹시 뜬 일시정지 걷기 — 매 프레임
func _tidy_stage() -> void:
	for rs in _map.find_children("*", "RoundStart", true, false):
		if not rs.is_queued_for_deletion():
			rs.emit_signal("finished")
			rs.queue_free()
	var hud: Node = _map.get_node_or_null("CombatHUD")
	if hud and "visible" in hud:
		hud.visible = false
	for n in get_tree().get_nodes_in_group("cooldown_pies"):
		if n is CanvasItem:
			n.visible = false

func _do(who: int, action: String, arg) -> void:
	var f: Fighter = _p1 if who == 1 else _p2
	var p: Pilot = _pilots.get(who)
	if f == null or not is_instance_valid(f) or p == null:
		return
	match action:
		"approach":
			p.approach_gap = float(arg)
		"move":
			p.approach_gap = -1.0
			p.dir = float(arg)
		"stop":
			p.approach_gap = -1.0
			p.dir = 0.0
		"jump":
			f.jump()
		"combo":
			p.combo_until = float(arg)
		"hit_close":
			p.hit_close = true
		"workout":
			f.use_map_skill()
		"ultimate":
			if f.skill_ultimate:
				f.skill_ultimate.cooldown_left = 0.0
			f.use_ultimate()
		"basic":
			f.use_basic_attack()
		"skill_1":
			if f.skill_1:
				f.skill_1.cooldown_left = 0.0
			f.use_skill_1()
		"skill_2":
			if f.skill_2:
				f.skill_2.cooldown_left = 0.0
			f.use_skill_2()
