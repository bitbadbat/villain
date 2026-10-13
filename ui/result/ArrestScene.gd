extends CanvasLayer

## 대전 최종 결과 3단계 — **연행 장면**(승리 화면 → 패배 화면 → 연행 → 결과 버튼).
## 『개그만화 보기 좋은 날』 "명탐정 우사미짱"의 쿠마키치 연행 장면 패러디다:
## 앞 왼쪽에 크게 잘린 경찰차, 가운데 밧줄을 쥔 경찰, 그 뒤로 수갑 찬 두 사람(이 판의 패자·승자)이
## 비스듬히 물러나며 작아지고, 오른쪽 뒤에서 **게임에 안 나오는 동네 사람 다섯**(OnlookerCrowd)과 얼굴 없는 무리가 구경한다.
## ⚠️ 구경꾼으로 로스터 리그를 세우지 말 것 — 둘이 싸웠는데 세 번째 로스터가 화면에 나온다(2026-10-11 사용자: "게임에 나오는 캐릭터들은 안 나오도록")
##
## **원근은 카메라 하나로 계산한다** — 지평선·소실점·카메라 높이·초점 거리로 바닥 선·경찰차·인물 크기·그림자를 전부 투영한다.
## 그래서 발 위치만 옮기면 크기·그림자·밧줄 굵기가 저절로 맞고, 밀고 들어가기(dolly)도 가까운 것일수록 더 커진다.
## 단위는 **캐릭터 키 = 1**.
##
## 사용: add_child 후 `play(info)`. 약 3초 뒤 `finished`. 끝나도 장면은 그대로 남는다(위에 결과 버튼이 뜬다).
## info 키: winner_rig / loser_rig(리그 경로), winner_name / loser_name, winner_p2_color / loser_p2_color, is_draw, map_path
## 이름(winner_name / loser_name)으로 연행 전용 얼굴(ResultFaces의 arrest_happy / arrest_sad)과 우는 아이(층간소음)를 고른다

signal finished

const ResultSfx = preload("res://ui/result/ResultSfx.gd")
const RopeScript = preload("res://ui/result/ArrestRope.gd")
const POLICE_RIG := "res://characters/police/PoliceRig.tscn"
const DEFAULT_BACKDROP := "res://ui/result/backdrops/PoliceStation.tres"
const BACKDROP_DIR := "res://ui/result/backdrops/"
const MobScript = preload("res://ui/result/MobCrowd.gd")
const GuideScript = preload("res://ui/result/PerspectiveGuide.gd")
const ResultFaces = preload("res://ui/result/ResultFaces.gd")
const KidScript = preload("res://ui/result/ArrestKid.gd")
const KID_SCENE_PATH := "res://characters/floornoise/Kid.tscn"
const LightingScript = preload("res://ui/result/ArrestLighting.gd")
const LIGHT_SHADER = preload("res://ui/result/ArrestLight.gdshader")
## 사람 위 빛 번짐 층의 z — 우는 아이(KID_Z)보다 위, 검은 막(FADE_Z)보다 아래
const AIR_LIGHT_Z := 10
## 우는 아이를 그리는 높이(리그 조각 z_index 1~3보다 위) / 검은 막(Fade) 높이 — 막은 무엇보다 위에 있어야 한다
const KID_Z := 4
const FADE_Z := 50
const BASE_SIZE := Vector2(1280, 720)

# --- 박자(실제 초, play() 기준) ---
# 처음엔 6초였는데 "너무 길어서 게임 템포가 느려졌다"(2026-10-08 사용자) -> 같은 순서를 3초로 줄였다
const FADE_IN := 0.2
const WALK_1 := Vector2(0.1, 1.05)
const WALK_2 := Vector2(1.8, 2.75)
## 첫 구간에서 걸어갈 몫(나머지는 두 번째 구간)
const WALK_SPLIT := 0.45
## 경찰이 멈춰 서서 뒤를 돌아보는 때 / 승자가 "어? 나도?" 하고 풀 죽는 때 / 경찰이 밧줄을 홱 당기는 때
const LOOKBACK_AT := 1.1
const BEAT_AT := 1.3
const TUG_AT := 1.65
const FINISH_AT := 3.0
## 엄마가 이긴 쪽(늦게 울기 시작한) 아이는 이만큼 운 뒤에 경찰한테 툭 맞는다
const KID_CRY_BEFORE_TAP := 0.9
## 경찰이 뒤돌아보기 시작하고 이만큼 뒤에 친다 — 고개 돌리는 중엔 머리가 납작해져서 그때 치면 머리가 없어 보였다(실측)
const KID_TAP_AFTER_LOOK := 0.45

@export_group("카메라(원근)")
## 지평선 높이(1280x720 기준 화면 px). 카메라가 사람 가슴 높이라 경찰 얼굴보다 아래에 온다
@export var horizon_y: float = 470.0
## 소실점 x — 연석·타일 세로선이 여기로 모인다
@export var vanish_x: float = 760.0
## 카메라 높이(캐릭터 키 = 1). 낮을수록 앞사람이 뒷사람보다 우뚝 솟아 보인다(원작처럼 올려다보는 맛)
@export var camera_height: float = 0.62
## 초점 거리(px) — 클수록 망원(원근이 약해짐)
@export var focal: float = 1500.0
## 연출 동안(FINISH_AT까지) 카메라가 앞으로 밀고 들어가는 거리(월드). 0이면 고정 화면
@export var dolly_distance: float = 0.16

@export_group("인물(시작할 때 발 위치)")
@export var police_feet: Vector2 = Vector2(530, 638)
@export var first_feet: Vector2 = Vector2(746, 622)
@export var second_feet: Vector2 = Vector2(942, 607)
## 경찰·패자·승자를 화면에서 이만큼 크게(1 = 캐릭터 키가 원근 그대로). 2026-10-11 사용자: "캐릭터 몸 크기 좀 키워주라".
## ⚠️ 건물은 안 커진다 — 건물은 문 높이(캐릭터 키 x door_height)로 놓는데, 그 "키"는 이 배율을 안 탄 원근 그대로다
@export var cast_scale: float = 1.25
## 경찰만 조금 더 크게(어른) — 1이면 다른 사람과 같은 키
@export var police_height_scale: float = 1.05
## 행렬이 왼쪽(경찰차 쪽)으로 걸어가는 거리(월드)
@export var walk_distance: float = 0.18
## 걷는 동안 리그에 넣는 걸음 세기(0~1)
@export var walk_speed_ratio: float = 0.46
## 끌려가는 걸음이라 보폭을 줄인다(리그 기본 11)
@export var walk_foot_stride: float = 7.0

@export_group("건물 배경")
## 인물들이 **이 건물 문에서 막 끌려 나온** 것처럼 보이게, 그림 속 문을 기준점으로 원근에 맞춰 놓는다(ArrestBackdropConfig.gd).
## **맵마다 그 맵 건물이 선다**: 대전에서 고른 맵 씬 이름과 같은 `ui/result/backdrops/<맵 이름>.tres`(예: Gym.tres)를 쓴다.
## 그 파일이 없거나 그림(texture)이 비어 있으면 이 기본 건물 — 비우면 경찰서(DEFAULT_BACKDROP)
@export var default_backdrop: Resource
## 건물이 땅에 닿는 화면 높이(밀고 들어가기 전). 지평선(horizon_y)에 가까울수록 건물이 멀어져 작아진다
@export var facade_base_y: float = 548.0
## 출입문 가운데가 올 화면 x — 행렬 바로 뒤라 "문에서 막 나온" 것처럼 보인다
@export var door_screen_x: float = 820.0

@export_group("원근 가이드")
## 켜면 지평선·소실점·문 자리·캐릭터 키를 겹쳐 그린다 — 배경 그림을 맞출 때 쓴다(건물은 반투명이 된다)
@export var show_perspective_guide: bool = false

@export_group("구경꾼")
## 동네 사람 다섯(회사원·아줌마·학생·할아버지·핸드폰으로 찍는 사람)의 **전신 그림**(투명 배경 PNG 한 장씩).
## i번째 그림이 crowd_feet[i] 자리에 선다. 크기는 그림의 칠해진 높이로 맞추니 캔버스 여백은 아무래도 된다.
## 비어 있는 자리는 얼굴 없는 구경꾼이 채운다(그림이 오기 전에도 무리가 차 보이게)
@export var onlooker_textures: Array[Texture2D] = []
## 자리마다 부위 리그 씬(`ui/result/onlookers/`, OnlookerRig.gd) — 있으면 위 그림 대신 리그가 선다(눈이 행렬을 따라가고 깜빡이고 입을 움직인다)
@export var onlooker_scenes: Array[PackedScene] = []
## 구경꾼 자리(화면 발 위치, 밀고 들어가기 전) — 앞(아래)에 있는 것일수록 크게 나온다. 행렬(경찰·두 사람)보다 늘 뒤에 그려진다.
## 0번 = **경찰과 패자 사이 먼 뒤**(작게 보여서 그 틈에 들어간다), 1~4번 = 승자 오른쪽에서 **오른쪽으로 갈수록 앞(아래)에 서는 사선**.
## 그림은 왼쪽(연행)을 보니 얼굴이 머리 왼쪽에 있는데, 오른쪽 사람이 앞에 서면 왼쪽 사람의 **뒤통수만** 가린다.
## 실제 그림은 소품(장바구니·지팡이) 때문에 옆으로 넓어서 간격 60px은 있어야 얼굴이 보이고, 승자 머리(오른쪽 끝 ~1005)에서
## 떨어져야 처음부터 안 가린다. 오른쪽 다섯을 한 줄로 몰았더니 얼굴이 반씩 가렸다(2026-10-11 실측)
@export var crowd_feet: Array[Vector2] = [Vector2(612, 549), Vector2(1045, 558), Vector2(1105, 564), Vector2(1165, 571), Vector2(1225, 578)]
## 구경꾼 키(캐릭터 키 = 1, 그림의 칠해진 높이 기준). 행렬이 cast_scale로 커져서 1이면 아이처럼 작아 보여 조금 키웠다
@export var onlooker_height: float = 1.15
## i번째 사람만 키를 바꾸고 싶을 때 배율(비우거나 0이면 1) — 예: 할아버지 0.92
@export var onlooker_sizes: Array[float] = []
## i번째 그림을 좌우로 뒤집어 세울지 — 그림이 연행(왼쪽) 반대쪽을 보고 있으면 켤 것
@export var onlooker_flip: Array[bool] = []

@export_group("얼굴 없는 무리")
## 얼굴 없는 구경꾼(MobCrowd) 발 위치(화면, 밀고 들어가기 전). back = 구경꾼(crowd_feet)보다 먼 줄, front = 가까운 줄
@export var mob_back_feet: Array[Vector2] = [
	Vector2(575, 553), Vector2(630, 556), Vector2(685, 552), Vector2(930, 551), Vector2(975, 553), Vector2(1020, 552), Vector2(1065, 554), Vector2(1110, 551),
	Vector2(1155, 553), Vector2(1200, 552), Vector2(1245, 554), Vector2(1290, 551), Vector2(1335, 553), Vector2(1380, 552), Vector2(1425, 554), Vector2(1470, 551),
	Vector2(952, 557), Vector2(997, 559), Vector2(1042, 558), Vector2(1087, 560), Vector2(1132, 557), Vector2(1177, 559), Vector2(1222, 558), Vector2(1267, 560),
	Vector2(1312, 557), Vector2(1357, 559), Vector2(1402, 558), Vector2(1447, 560), Vector2(1492, 557),
]
@export var mob_front_feet: Array[Vector2] = [Vector2(1300, 588), Vector2(1368, 594), Vector2(1436, 589), Vector2(1504, 595)]
## 얼굴 없는 구경꾼 밝기(1 = 하얀 바탕 그대로). 너무 튄다고 해서 낮췄다(2026-10-10 사용자: "너무 밝아")
@export_range(0.3, 1.0, 0.01) var mob_shade: float = 0.78

@export_group("밧줄")
## 밧줄 굵기(월드) / 처짐(두 점 거리 대비)
@export var rope_thickness: float = 0.02
@export var rope_sag: float = 0.17

@export_group("우는 아이(층간소음)")
## 이 캐릭터가 끌려가면 아이(`Kid.tscn`)가 "뿌에엥" 울며 뒤를 쫓아온다(ArrestKid.gd). GameState.CHARACTERS 이름 —
## 이름이 안 넘어온 경우를 위해 리그 경로로도 알아본다. 엄마 품의 작은 아이(리그 `Carry`)는 숨긴다
@export var kid_for_character: String = "층간소음 빌런"
@export_file("*.tscn") var kid_for_rig: String = "res://characters/floornoise/FloorNoiseRig.tscn"
## 아이 키(캐릭터 키 = 1, 칠해진 높이 기준) — cast_scale도 곱해진다. 엄마 품 아이는 0.42쯤이다
@export var kid_height: float = 0.5
## 엄마 발에서 아이 발까지(월드): x = 뒤쪽(행렬 반대, 화면 오른쪽), y = 깊이(음수면 카메라 쪽 — 행렬 앞에 서서 안 가려진다)
@export var kid_offset: Vector2 = Vector2(0.34, -0.6)
## 행렬보다 이만큼(초) 늦게 따라 걷는다 — 종종걸음으로 뒤쫓는 맛
@export var kid_lag: float = 0.12
## 엄마가 처음부터 끌려가는 쪽(패자)일 때 울기 시작하는 때(초). 승자 엄마면 "어? 나도?"(BEAT_AT) 직후에 터진다
@export var kid_cry_at: float = 0.12
## 툭 맞을 때 아이가 서는 자리 — 경찰 발에서 (뒤쪽 x, 카메라 쪽 z), 월드 단위(캐릭터 키 = 1)
@export var kid_tap_spot: Vector2 = Vector2(0.42, -0.3)

@onready var _stage: Node2D = $Stage
@onready var _backdrop: Node2D = $Stage/Backdrop
@onready var _building: Sprite2D = $Stage/Building
@onready var _crowd_layer: Node2D = $Stage/Crowd
@onready var _line_layer: Node2D = $Stage/Procession
@onready var _car: Node2D = $Stage/Car
@onready var _fade: ColorRect = $Fade

## 리그 경로 -> [보이는 영역(리그 좌표), 머리 영역] — 같은 리그를 다시 잴 일이 없게
static var _bounds_cache: Dictionary = {}
## 그림 경로 -> 불투명 영역
static var _opaque_cache: Dictionary = {}
## `warm_up()`이 스레드로 미리 읽기 시작한 경로들 — `release_warm()`이 손을 놓는다
static var _warm_paths: Array[String] = []

var _info: Dictionary = {}
var _playing: bool = false
var _sent_finished: bool = false
## play() 이후 흐른 실제 시간 / 장면이 뜬 뒤 흐른 실제 시간(경광등·구름은 play 전에도 돈다)
var _time: float = 0.0
var _clock: float = 0.0
var _last_usec: int = 0
var _dolly: float = 0.0
var _actors: Array = []
var _police: Dictionary = {}
var _first: Dictionary = {}
var _second: Dictionary = {}
var _rope_a: Node2D = null
var _rope_b: Node2D = null
var _siren: AudioStreamPlayer = null
## [시각, Callable] — 시간 순서대로 한 번씩 부른다
var _events: Array = []
var _next_event: int = 0
var _building_world: Vector3 = Vector3.ZERO
var _building_height: float = 956.0
var _building_scale: float = 0.4
## 그림 가장자리를 하늘로 녹이는 재질(씬에 붙어 있던 것) — 끄는 그림이면 떼었다가 다시 붙인다
var _edge_material: Material = null
var _mob_back: Node2D = null
var _mob_front: Node2D = null
var _guide: Node2D = null
## 얼굴 없는 무리의 낮 공기색(MobCrowd 기본값) — 밤(ArrestBackdropConfig.night)에서 낮으로 돌릴 때 쓴다
var _day_haze: Color = Color(0.85, 0.89, 0.95)
## 경광등 박자 시계 — 사이렌이 울리면 소리가 들리는 지점에 맞추고, 없거나 꺼지면 이어서 센다
var _siren_clock: float = 0.0
## 우는 아이들 — {node, parent(엄마 actor), cry_at, tap_at, slot} (거울전이면 둘)
var _kids: Array = []
## 조명(ArrestLighting) — 건물 위·사람 밑 빛 층 / 사람 위 번짐 층 / 인물 조각이 같이 쓰는 윤곽광 재질(ArrestLight.gdshader)
var _ground_light: Node2D = null
## 낮 그림 명암(곱하기) — 건물 바로 위, GroundLight 밑
var _shade_light: Node2D = null
var _air_light: Node2D = null
var _vignette: Node2D = null
var _light_mat: ShaderMaterial = null
## 경광등이 인물을 물들이는 세기(맵 설정 siren_power)
var _siren_power: float = 0.15

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 리그들이 이번 프레임 자세를 다 잡은 **뒤에** 손·고개를 덮어써야 해서 맨 마지막에 돈다
	process_priority = 100
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 노드 순서로는 맨 마지막이지만 z_index가 높은 조각(리그 손 1~3, 우는 아이 KID_Z)은 그 위에 그려진다 — 검은 막을 맨 위로
	_fade.z_index = FADE_Z
	_fade.color = Color(0, 0, 0, 1)
	_last_usec = Timers.now_usec()
	_edge_material = _building.material
	_build_mobs()
	_build_onlookers()
	_build_lighting()
	_light_parts(_crowd_layer)
	_apply_backdrop(default_backdrop if default_backdrop != null else load(DEFAULT_BACKDROP))
	if show_perspective_guide:
		_guide = Node2D.new()
		_guide.set_script(GuideScript)
		_stage.add_child(_guide)
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_update_scene()

## 이 장면에 나올 리그(경찰 + extra — 보통 이 씬과 두 선수 리그)를 **뒤에서 미리 읽기 시작한다**.
## play()가 리그를 한꺼번에 읽느라 검은 화면에서 1~2초 멈췄다(실측) — 승리·패배 화면이 도는 동안 불러 둘 것.
## 구경꾼 그림은 이 씬(ArrestScene.tscn)에 꽂혀 있어서 씬을 읽을 때 같이 읽힌다(구경꾼이 로스터 리그이던 때와 달리 리그를 더 안 읽는다).
## 다 읽힌 리그는 손을 놓기(`release_warm`) 전까지 캐시에 남아 있어서 play()의 load()가 곧바로 받아 간다
static func warm_up(extra: Array = []) -> void:
	# 헤드리스(가짜 렌더러)에선 스레드로 그림을 만들면 "Parameter "t" is null"(texture_2d_initialize) 에러가 쏟아진다(실측).
	# 실제 창에선 안 나고, 헤드리스 검사에서 가짜 경보가 되므로 끈다
	if DisplayServer.get_name() == "headless":
		return
	var paths: Array = [POLICE_RIG]
	paths.append_array(extra)
	for path in paths:
		var p: String = str(path)
		if p == "" or _warm_paths.has(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_warm_paths.append(p)

## 미리 읽기에서 손을 놓는다 — 장면에 쓰인 리그는 장면이 붙들고 있고, 안 쓰인 것은 메모리에서 풀린다
static func release_warm() -> void:
	for p in _warm_paths:
		ResourceLoader.load_threaded_get(p)
	_warm_paths.clear()

func _exit_tree() -> void:
	# 끝나기 전에 지워져도 미리 읽기가 붙든 리그가 메모리에 남지 않게
	release_warm()

## 연출을 시작한다. add_child 다음에 부를 것
func play(info: Dictionary) -> void:
	if _playing:
		return
	_info = info
	_playing = true
	_time = 0.0
	# 싸운 맵의 건물 그림이 있으면 그걸로 — 그 건물 문에서 끌려 나온 셈이다(그림이 비어 있으면 기본 건물 그대로)
	var map_path: String = str(info.get("map_path", ""))
	var map_config: String = BACKDROP_DIR + map_path.get_file().get_basename() + ".tres"
	if map_path != "" and ResourceLoader.exists(map_config):
		_apply_backdrop(load(map_config))
	_build_cast()
	_events = [
		[LOOKBACK_AT, _police_look_back],
		[BEAT_AT, _winner_deflates],
		[TUG_AT + 0.05, _tug_squash],
		[FINISH_AT, _finish],
	]
	# 아이를 툭 치기 직전에 경찰이 뒤돌아본다(엄마가 진 쪽은 원래 뒤돌아보는 때와 겹친다 — 다시 불러도 이어서 본다)
	for kid in _kids:
		var look_at: float = float(kid["tap_at"]) - KID_TAP_AFTER_LOOK
		# 원래 뒤돌아보는 때와 겹치면 한 번만(다시 부르면 고개를 처음부터 다시 돌린다)
		if absf(look_at - LOOKBACK_AT) > 0.05:
			_events.append([look_at, _police_look_back])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_next_event = 0
	_siren = ResultSfx.play(self, ResultSfx.SIREN, -12.0, 1.0, true)
	_update_scene()

func _process(_delta: float) -> void:
	# 실제 시간으로 잰다 — KO 슬로처럼 Engine.time_scale이 바뀌어 있어도 박자가 안 흔들린다
	var now: int = Timers.now_usec()
	var dt: float = minf(float(now - _last_usec) / 1000000.0, 0.05)
	_last_usec = now
	_clock += dt
	# 경광등은 사이렌에 맞춘다 — 지금 **들리는** 지점(출력 지연까지 뺀 값)을 잰다. 소리가 없거나 꺼지면 같은 박자로 이어서 센다
	if is_instance_valid(_siren) and _siren.playing:
		_siren_clock = _siren.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	else:
		_siren_clock += dt
	if _playing:
		_time += dt
		while _next_event < _events.size() and _time >= float(_events[_next_event][0]):
			var cb: Callable = _events[_next_event][1]
			_next_event += 1
			cb.call()
	_update_scene()

# ---------------------------------------------------------------- 배치

## 넓은 화면이면 좌우(또는 위아래)로 더 보인다 — 구도는 가운데에 두고 배경만 끝까지 채운다
func _fit_to_screen() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	_stage.position = rect.position + (rect.size - BASE_SIZE) * 0.5
	_backdrop.set("view_rect", Rect2(rect.position - _stage.position, rect.size))
	_update_guide()

func _build_cast() -> void:
	var is_draw: bool = bool(_info.get("is_draw", false))
	var winner_rig: String = str(_info.get("winner_rig", ""))
	var loser_rig: String = str(_info.get("loser_rig", ""))
	# 행렬 — 뒤(둘째) → 둘째 밧줄 → 첫째 → 첫째 밧줄 → 경찰 순으로 쌓는다.
	# 밧줄은 묶인 사람의 손(앞) 위, 그 앞사람 몸 뒤로 지나가야 자연스럽다
	_second = _make_actor(winner_rig, second_feet, _line_layer, &"second", bool(_info.get("winner_p2_color", false)))
	_rope_b = _make_rope()
	_first = _make_actor(loser_rig, first_feet, _line_layer, &"first", bool(_info.get("loser_p2_color", false)))
	_rope_a = _make_rope()
	_police = _make_actor(POLICE_RIG, police_feet, _line_layer, &"police", false)
	for actor in [_second, _first, _police]:
		if not actor.is_empty():
			_actors.append(actor)
	# 표정 — 패자는 처음부터 찡그리고 고개를 푹, 승자는 아직 이긴 기분(신난 얼굴 + 턱 들기)이다가 BEAT에 풀이 죽는다.
	# 무승부면 둘 다 무표정(우사미짱식 멍한 얼굴)으로 시작해 BEAT에 같이 식은땀. 얼굴은 _prepare_faces()가 정해 두고 _apply_face()가 매 프레임 씌운다
	if not is_draw:
		if not _second.is_empty():
			_second["tilt_from"] = -6.0
	else:
		for actor in [_first, _second]:
			if not actor.is_empty():
				actor["tilt_from"] = 3.0
	_prepare_faces(_second, str(_info.get("winner_name", "")), true, is_draw)
	_prepare_faces(_first, str(_info.get("loser_name", "")), false, is_draw)
	for actor in [_first, _second]:
		if not actor.is_empty():
			_add_cuffs(actor)
	# 층간소음 빌런이 끌려가면 아이가 울며 쫓아온다 — 패자 엄마면 처음부터, 승자(무승부 포함) 엄마면 "어? 나도?" 직후에
	_add_kid(_first, str(_info.get("loser_name", "")), kid_cry_at if not is_draw else BEAT_AT + 0.08)
	_add_kid(_second, str(_info.get("winner_name", "")), BEAT_AT + 0.08)

func _make_rope() -> Node2D:
	var rope := Node2D.new()
	rope.set_script(RopeScript)
	_line_layer.add_child(rope)
	return rope

## 리그 하나를 [발 기준 노드 > 그림자 + 기울기 > 크기·방향 > 리그]로 감싸 붙인다.
## 리그 루트의 scale은 리그가 스쿼시에 쓰므로 직접 안 건드린다(⚠️ BodyRig 규칙) — 크기·좌우는 holder가 맡는다
func _make_actor(path: String, feet: Vector2, layer_node: Node2D, role: StringName, p2_color: bool) -> Dictionary:
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return {}
	var rig: BodyRig = scene.instantiate() as BodyRig
	if rig == null:
		return {}
	var node := Node2D.new()
	node.name = String(role)
	var shadow := ShadowBlob.new()
	node.add_child(shadow)
	var lean := Node2D.new()
	node.add_child(lean)
	var holder := Node2D.new()
	lean.add_child(holder)
	# add_child가 _ready를 바로 부르므로 리그 값은 그 전에 넣는다
	rig.idle_gestures = role == &"police"   # 경찰은 뒤돌아보기(play_lookback)가 가만히 서 있을 때만 이어져서 켜 둔다
	rig.idle_motion_delay = 9999.0          # 대신 저절로 나오는 몸짓(머리 긁기 등)은 막는다
	rig.foot_stride = walk_foot_stride
	rig.body_bob = 3.0
	layer_node.add_child(node)
	holder.add_child(rig)
	if p2_color:
		rig.set_player_two(true)
	_light_parts(rig)
	# 키는 소품을 뺀 몸으로 잰다(키보드·가방 크기에 키가 휘둘리지 않게)
	_hide_props(rig)
	var measured: Array = _measure(rig, path)
	var bounds: Rect2 = measured[0]
	var actor: Dictionary = {
		"role": role, "path": path, "node": node, "lean": lean, "holder": holder, "rig": rig, "shadow": shadow,
		"world": _ground_to_world(feet),
		"mul": cast_scale * (police_height_scale if role == &"police" else 1.0),
		"bottom": bounds.end.y, "rig_h": maxf(bounds.size.y, 1.0), "head_rect": measured[1],
		"hand_l": rig.get_node_or_null("HandL"), "hand_r": rig.get_node_or_null("HandR"),
		"head": rig.get_node_or_null("Head"), "body": rig.get_node_or_null("Body"),
		"tilt_from": 9.0, "tilt_to": 9.0,
		"sweat": null, "cuffs": null,
	}
	for part_name in ["hand_l", "hand_r", "head", "body"]:
		var part: Node2D = actor[part_name]
		actor[part_name + "_rest"] = part.position if part != null else Vector2.ZERO
	return actor

## 손에 든 무기·소품은 압수 — 수갑 찬 손에 키보드·소주병이 붙어 있으면 이상하다.
## 리그가 매 프레임 다시 켜는 것도 있어서(악플러 키보드 등) 매 프레임 부른다
static func _hide_props(rig: Node2D) -> void:
	for hold_name in ["HandRHold", "HandLHold"]:
		var hold: CanvasItem = rig.get_node_or_null(hold_name) as CanvasItem
		if hold != null and hold.visible:
			hold.visible = false
	for hand_name in ["HandL", "HandR"]:
		var hand: Node = rig.get_node_or_null(hand_name)
		if hand == null:
			continue
		for child in hand.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				(child as CanvasItem).visible = false

func _add_cuffs(actor: Dictionary) -> void:
	var rig: BodyRig = actor["rig"]
	var hand_l: Sprite2D = actor["hand_l"] as Sprite2D
	var hand_r: Sprite2D = actor["hand_r"] as Sprite2D
	if hand_l == null or hand_r == null:
		return
	var cuffs := Cuffs.new()
	cuffs.hand_l = hand_l
	cuffs.hand_r = hand_r
	var hand_size: Vector2 = hand_r.texture.get_size() * hand_r.scale.abs() if hand_r.texture != null else Vector2(18, 16)
	cuffs.back = hand_size.x * 0.3
	cuffs.ring_size = Vector2(hand_size.x * 0.12, hand_size.y * 0.34)
	rig.add_child(cuffs)
	actor["cuffs"] = cuffs

# ---------------------------------------------------------------- 얼굴

## 묶인 사람의 얼굴 세 장을 정해 둔다 — 평소 / 신난(승자가 풀 죽기 전) / 시무룩(끌려가는 동안: 패자는 내내, 승자는 풀 죽은 뒤).
## 승패 전용 그림(ResultFaces의 arrest_happy / arrest_sad)이 있으면 그것, 없으면 리그에 있는 얼굴(액션 표정 / 피격 표정 / 평소 얼굴).
##
## ⚠️ **얼굴은 이 장면이 매 프레임 직접 씌운다**(`_apply_face`) — 리그의 표정 함수(play_hurt_face·set_action_face)를 부르지 않는다.
## 예전엔 패자에게 0.25초마다 `play_hurt_face()`를 다시 걸었는데, 주정뱅이 머리가 반짝반짝 깜빡였다(2026-10-11 팀 피드백).
## 원인(실측): 표정 함수는 머리에 **씬에 적힌 배율**을 넣는데(주정뱅이 0.045 x 0.0507 — 가로세로가 다르다),
## 리그는 가만히 선 몸짓(idle)이 아닐 때마다 매 프레임 `BodyRig._end_lookback()`이 `scale.x = scale.y`로 **가로를 세로에 맞춰 버린다**(0.0507 x 0.0507) —
## 묶인 두 사람은 idle_gestures를 꺼 둬서 내내 그 상태다.
## 그래서 다시 걸 때마다 한 프레임만 머리가 11% 홀쭉해졌다가 돌아왔다 = 초당 4번 깜빡임. 악플러(0.049 x 0.052)도 덜할 뿐 같았다.
## 리그(게임 쪽)는 그대로 두고, 이 장면이 리그 **다음에**(process_priority 100) 그림·배율·offset을 한 번에 같은 값으로 덮어써서 서로 안 싸우게 했다
func _prepare_faces(actor: Dictionary, character_name: String, is_winner: bool, is_draw: bool) -> void:
	if actor.is_empty():
		return
	var rig: BodyRig = actor["rig"]
	var head: Sprite2D = actor["head"] as Sprite2D
	if head == null:
		return
	actor["head_sprite"] = head
	var rest_tex: Texture2D = rig._head_rest_texture if rig._head_rest_texture != null else head.texture
	var rest_scale: Vector2 = rig._head_rest_scale if rig._head_rest_scale != Vector2.ZERO else head.scale
	var rest: Dictionary = _rig_face(rest_tex, rest_scale, head.offset, Vector2.ZERO)
	actor["face_rest"] = rest
	# 신난 얼굴 — 이긴 쪽만(무승부는 처음부터 멍한 평소 얼굴). 일진 = 신남일진
	var happy: Dictionary = rest
	if is_winner and not is_draw:
		var happy_tex: Texture2D = ResultFaces.face(character_name, "arrest_happy")
		if happy_tex != null:
			happy = _fitted_face(rig, head, rest, happy_tex)
		elif rig.action_head_texture != null:
			happy = _rig_face(rig.action_head_texture, rig.action_head_scale if rig.action_head_scale != Vector2.ZERO else rest_scale, head.offset, Vector2.ZERO)
	actor["face_happy"] = happy
	# 시무룩한 얼굴 — 전용 그림이 없으면 패자는 피격 표정(찡그림), 승자·무승부는 평소 얼굴(예전과 같다)
	var sad: Dictionary = rest
	var sad_tex: Texture2D = ResultFaces.face(character_name, "arrest_sad")
	if sad_tex != null:
		sad = _fitted_face(rig, head, rest, sad_tex)
	elif not is_winner and not is_draw and rig.hurt_head_texture != null:
		sad = _rig_face(rig.hurt_head_texture, rig.hurt_head_scale if rig.hurt_head_scale != Vector2.ZERO else rest_scale, head.offset, rig.hurt_head_offset)
	actor["face_sad"] = sad

## 지금 보일 얼굴 — 패자는 내내 시무룩, 승자(와 무승부의 둘)는 BEAT_AT까지 신난(무승부는 평소) 얼굴이다가 시무룩
func _face_now(actor: Dictionary) -> Dictionary:
	if actor["role"] == &"first" and not bool(_info.get("is_draw", false)):
		return actor.get("face_sad", {})
	return actor.get("face_happy", {}) if _time < BEAT_AT else actor.get("face_sad", {})

## 얼굴을 머리에 씌운다 — 리그가 이번 프레임 머리를 다 만진 **뒤**라 이 값이 그대로 화면에 나간다
func _apply_face(actor: Dictionary) -> void:
	var face: Dictionary = _face_now(actor)
	var head: Sprite2D = actor.get("head_sprite") as Sprite2D
	if face.is_empty() or head == null:
		return
	head.texture = face["tex"]
	head.scale = face["scale"]
	head.offset = face["offset"]

## 리그에 들어 있는 얼굴 한 장 — {그림, 배율, offset}. shift = 리그가 그 표정에 더하는 머리 위치 보정(px, hurt_head_offset)
func _rig_face(tex: Texture2D, authored_scale: Vector2, base_offset: Vector2, shift: Vector2) -> Dictionary:
	var s: Vector2 = _shown_head_scale(authored_scale)
	return {"tex": tex, "scale": s, "offset": base_offset + shift / s}

## 머리가 **실제로 보이는** 배율 — 움직이는 리그는 `BodyRig._end_lookback()`이 매 프레임 가로를 세로에 맞추므로(scale.x = scale.y)
## 게임에서 움직일 때도, 이 장면의 예전 모습(깜빡이지 않던 프레임)도 그 배율이다. 같은 모양으로 써야 얼굴 크기가 안 바뀐다(가로세로가 같은 리그는 그대로)
static func _shown_head_scale(s: Vector2) -> Vector2:
	return Vector2(absf(s.y) * (-1.0 if s.x < 0.0 else 1.0), s.y)

## 승패 전용 얼굴 그림을 **평소 머리와 같은 화면 크기·자리**에 보이게 맞춘다(MatchEnding._use_face와 같은 방법).
##  - 크기: 캔버스가 평소 머리와 같으면(같은 틀에 그린 표정 — 신남일진) 평소 배율 그대로,
##    다르면 살색 높이(`BodyRig._skin_height_of`, 헬스장 표정과 같은 방법)로, 그것도 못 재면 보이는 영역 높이로 맞춘다
##  - 자리: 그림 속 얼굴이 캔버스에서 치우친 정도가 달라도 **보이는 영역 가운데**가 평소 머리와 같은 데 오게 offset을 민다
func _fitted_face(rig: BodyRig, head: Sprite2D, rest: Dictionary, tex: Texture2D) -> Dictionary:
	var rest_tex: Texture2D = rest["tex"]
	var rest_scale: Vector2 = rest["scale"]
	var s: Vector2 = rest_scale
	if rest_tex != null and not tex.get_size().is_equal_approx(rest_tex.get_size()):
		var k: float = rig._opaque_rect_of(rest_tex).size.y / maxf(rig._opaque_rect_of(tex).size.y, 1.0)
		var here: float = BodyRig._skin_height_of(tex)
		var there: float = BodyRig._skin_height_of(rest_tex)
		if here > 1.0 and there > 1.0:
			k = there / here
		s = rest_scale * k
	var offset: Vector2 = rest["offset"]
	if rest_tex != null:
		# 평소 머리의 보이는 영역 가운데가 리그에서 놓이는 자리(머리 원점 기준, 배율 적용) = 새 얼굴의 그 자리
		var rest_c: Vector2 = (_tex_center(rig, rest_tex, head) + Vector2(rest["offset"])) * rest_scale
		offset = rest_c / s - _tex_center(rig, tex, head)
	return {"tex": tex, "scale": s, "offset": offset}

## 그림의 보이는 영역 가운데 — 머리 스프라이트 기준(배율·offset 전, 그 스프라이트의 좌우 뒤집힘 반영)
static func _tex_center(rig: BodyRig, tex: Texture2D, sprite: Sprite2D) -> Vector2:
	var size: Vector2 = tex.get_size()
	var px: Rect2 = rig._opaque_rect_of(tex)
	if sprite.flip_h:
		px.position.x = size.x - px.end.x
	if sprite.flip_v:
		px.position.y = size.y - px.end.y
	return px.get_center() - (size * 0.5 if sprite.centered else Vector2.ZERO)

# ---------------------------------------------------------------- 우는 아이

## 엄마가 아이 딸린 캐릭터(층간소음 빌런)면 아이를 만들어 행렬 앞쪽에 세운다. 엄마 품의 작은 아이는 숨긴다(둘로 보이면 안 된다).
## 행렬(경찰·두 사람) **다음에** 붙여서 그 위에 그려진다 — 아이는 행렬보다 카메라 쪽(kid_offset.y < 0)에 선다
func _add_kid(actor: Dictionary, character_name: String, cry_at: float) -> void:
	if actor.is_empty():
		return
	var is_parent: bool = (kid_for_character != "" and character_name == kid_for_character) \
		or (kid_for_rig != "" and str(actor.get("path", "")) == kid_for_rig)
	if not is_parent:
		return
	(actor["rig"] as BodyRig).carrying = false
	var node := Node2D.new()
	node.set_script(KidScript)
	node.name = "Kid" + String(actor["role"]).capitalize()
	# 아이는 행렬보다 카메라 쪽에 서므로 행렬 위에 그린다 — 리그 손·소품이 z_index 1~3이라 노드 순서만으로는
	# 승자 손(수갑)이 아이 얼굴·"뿌에엥" 글자를 덮었다(실측). Fade는 _ready에서 더 위(FADE_Z)로 올려 둔다
	node.z_index = KID_Z
	_line_layer.add_child(node)   # _ready()가 아이 그림을 만든다 — 그 뒤에 잰다
	_light_parts(node)
	var measured: Array = _measure(node.call("kid_root"), KID_SCENE_PATH)
	node.call("set_bounds", measured[0])
	# 울다가 경찰한테 "툭" 맞는 때 — 경찰이 다 돌아본 뒤(KID_TAP_AFTER_LOOK)에 친다. 엄마가 진 쪽은 원래 뒤돌아보는 때(LOOKBACK_AT) 기준,
	# 늦게 울기 시작한 아이(엄마가 이긴 쪽·무승부)는 KID_CRY_BEFORE_TAP초 울린 뒤
	var tap_at: float = maxf(cry_at + KID_CRY_BEFORE_TAP, LOOKBACK_AT + KID_TAP_AFTER_LOOK)
	_kids.append({"node": node, "parent": actor, "cry_at": cry_at, "tap_at": tap_at, "slot": _kids.size()})

## 아이 한 프레임 — 엄마 발에서 kid_offset만큼 떨어진 땅을 같은 카메라로 투영하고, 행렬을 kid_lag초 늦게 따라 걷는다
func _update_kid(kid: Dictionary, tug_s: float) -> void:
	var node: Node2D = kid["node"]
	var parent: Dictionary = kid["parent"]
	var t: float = _time - kid_lag
	var walked: float = -walk_distance * _walk_progress(t) if _playing else 0.0
	var walking: bool = _playing and ((t > WALK_1.x and t < WALK_1.y) or (t > WALK_2.x and t < WALK_2.y))
	var base: Vector3 = parent["world"]
	var world: Vector3 = base + Vector3(kid_offset.x + walked, 0.0, kid_offset.y)
	# 툭 맞기 전에 경찰 옆(뒤쪽)으로 쫓아간다 — 맞은 뒤에도 그 자리에서 행렬을 따라 걷는다
	var tap_at: float = float(kid["tap_at"])
	var approach: float = smoothstep(tap_at - 0.65, tap_at - 0.12, _time) if _playing and not _police.is_empty() else 0.0
	if approach > 0.0:
		var police_walked: float = -walk_distance * _walk_progress(_time)
		var spot: Vector2 = kid_tap_spot + Vector2(0.22, -0.12) * float(kid["slot"])
		var near: Vector3 = (_police["world"] as Vector3) + Vector3(spot.x + police_walked, 0.0, spot.y)
		world = world.lerp(near, approach)
		walking = walking or (approach < 1.0)
	node.position = _project(world)
	var px: float = _px_per_unit(world.z) * cast_scale * kid_height
	var rx: float = px * 0.5
	var shadow := Vector2(rx, rx * camera_height / maxf(world.z - _dolly, 0.05) * 1.25)
	# 밧줄이 홱 당겨지면 행렬이 휘청하는 걸 보고 한 박자 늦게 따라 휘청
	var lurch: float = _pulse(tug_s - 0.22, 0.1, 5.0)
	var cry_t: float = _time - float(kid["cry_at"]) if _playing else -1.0
	# "뿌에엥" 글자가 경찰·두 사람의 얼굴을 덮지 않게 그 머리 네모와 보이는 화면을 아이 좌표로 넘긴다
	var to_kid: Transform2D = node.get_global_transform().affine_inverse()
	var avoid: Array = []
	for actor in _actors:
		var head_rect: Rect2 = actor["head_rect"]
		if head_rect.has_area():
			avoid.append(_rect_in(to_kid * (actor["rig"] as Node2D).get_global_transform(), head_rect))
	# 거울전(둘 다 층간소음)이면 다른 아이의 얼굴·이미 자리 잡은 글자도 피한다
	for other in _kids:
		if other == kid:
			continue
		var other_node: Node2D = other["node"]
		for box in [other_node.call("head_box_global"), other_node.call("text_box_global")]:
			if (box as Rect2).has_area():
				avoid.append(_rect_in(to_kid, box))
	var vis: Rect2 = get_viewport().get_visible_rect()
	node.call("set_layout_hints", avoid, _rect_in(to_kid, vis))
	var sulk_t: float = _time - tap_at if _playing and _time >= tap_at and not _police.is_empty() else -1.0
	node.call("tick", px, shadow, -1.0, cry_t, _clock, walking, lurch, sulk_t)

# ---------------------------------------------------------------- 매 프레임

func _update_scene() -> void:
	if _playing:
		var k: float = clampf(_time / FINISH_AT, 0.0, 1.0)
		_dolly = dolly_distance * (1.0 - pow(1.0 - k, 2.2))
		_fade.color.a = 1.0 - smoothstep(0.0, FADE_IN, _time)
	var walking: bool = _playing and ((_time > WALK_1.x and _time < WALK_1.y) or (_time > WALK_2.x and _time < WALK_2.y))
	var walked: float = -walk_distance * _walk_progress(_time) if _playing else 0.0
	var tug_s: float = _time - TUG_AT
	for actor in _actors:
		_update_actor(actor, walking, walked, tug_s)
	for kid in _kids:
		_update_kid(kid, tug_s)
	_police_tap()
	_update_ropes(tug_s)
	_update_building()
	_backdrop.set("vanish_x", vanish_x)
	_backdrop.set("horizon_y", horizon_y)
	_backdrop.set("camera_height", camera_height)
	_backdrop.set("focal", focal)
	_backdrop.set("dolly", _dolly)
	_backdrop.set("time", _clock)
	var b_left: float = _project(_building_world).x
	_backdrop.set("building_span", Vector2(b_left, b_left + _building.region_rect.size.x * _building.scale.x))
	_car.set("vanish_x", vanish_x)
	_car.set("horizon_y", horizon_y)
	_car.set("camera_height", camera_height)
	_car.set("focal", focal)
	_car.set("dolly", _dolly)
	_car.set("time", _clock)
	var tone: Vector2 = ResultSfx.siren_tone_at(maxf(_siren_clock, 0.0))
	_car.set("siren_tone", int(tone.x))
	_car.set("tone_time", tone.y)
	_backdrop.set("facade_ground_y", _project(_building_world).y)
	_update_lighting()
	for layer_node in [_mob_back, _mob_front, _crowd_layer]:
		if layer_node == null:
			continue
		layer_node.set("vanish_x", vanish_x)
		layer_node.set("horizon_y", horizon_y)
		layer_node.set("camera_height", camera_height)
		layer_node.set("focal", focal)
		layer_node.set("dolly", _dolly)
		layer_node.set("time", _clock)
	# 구경꾼은 리그들이 이번 프레임 움직인 뒤 자리를 맞춘다(그림자·몸짓까지). 눈은 행렬 가운데(두 사람 머리 사이)를 본다
	_crowd_layer.set("look_target", _procession_center())
	_crowd_layer.call("refresh")

func _update_actor(actor: Dictionary, walking: bool, walked: float, tug_s: float) -> void:
	var role: StringName = actor["role"]
	var rig: BodyRig = actor["rig"]
	var offset: float = walked
	var lean: float = 0.0
	rig.manual_speed_ratio = walk_speed_ratio if walking else 0.0
	if role == &"police":
		lean = 0.05 * _pulse(tug_s, 0.08, 7.0)   # 당기면서 몸이 뒤로 살짝 젖혀진다
	else:
		# 홱 당겨지면 앞으로 휘청 — 둘째는 줄이 팽팽해지는 만큼 조금 늦게
		var delay: float = 0.05 if role == &"first" else 0.14
		var lurch: float = _pulse(tug_s - delay, 0.1, 5.0) * (1.0 if role == &"first" else 0.85)
		offset -= 0.045 * lurch
		lean = -0.085 * lurch
	var base_world: Vector3 = actor["world"]
	var world: Vector3 = base_world + Vector3(offset, 0.0, 0.0)
	var node: Node2D = actor["node"]
	node.position = _project(world)
	(actor["lean"] as Node2D).rotation = lean
	var px: float = _px_per_unit(world.z) * float(actor["mul"])
	var k: float = px / float(actor["rig_h"])
	var holder: Node2D = actor["holder"]
	# 전원 왼쪽(경찰차 쪽)을 본다 — 좌우는 holder의 scale.x 부호로만
	holder.scale = Vector2(-k, k)
	holder.position = Vector2(0.0, -float(actor["bottom"]) * k)
	var shadow: ShadowBlob = actor["shadow"]
	var rx: float = px * 0.3
	shadow.set_radius(Vector2(rx, rx * camera_height / maxf(world.z - _dolly, 0.05) * 1.25))
	_hide_props(rig)
	_pose_hands(actor, tug_s)

## 리그가 이번 프레임 잡은 자세 위에 손·고개를 덮어쓴다(이 노드가 리그들보다 늦게 돈다)
func _pose_hands(actor: Dictionary, tug_s: float) -> void:
	var role: StringName = actor["role"]
	var body: Node2D = actor["body"]
	var body_rest: Vector2 = actor["body_rest"]
	var bob: Vector2 = body.position - body_rest if body != null else Vector2.ZERO
	var hand_l: Node2D = actor["hand_l"]
	var hand_r: Node2D = actor["hand_r"]
	if role == &"police":
		# 밧줄 쥔 손(뒤쪽 손)은 허리 뒤에 — 당길 때 앞으로 홱
		if hand_l != null:
			var pull: float = _pulse(tug_s, 0.08, 7.0)
			var rest_l: Vector2 = actor["hand_l_rest"]
			hand_l.position = rest_l + Vector2(5.0 + 10.0 * pull, 6.0) + bob
			hand_l.rotation = 0.0
		return
	# 묶인 두 사람 — 두 손을 배 앞에 모은다(수갑)
	if hand_r != null and hand_l != null:
		var rest_r: Vector2 = actor["hand_r_rest"]
		var cuff_r := Vector2(rest_r.x * 0.6, rest_r.y + 7.0)
		hand_r.position = cuff_r + bob
		hand_l.position = cuff_r + Vector2(-6.5, 2.0) + bob
		hand_r.rotation = 0.0
		hand_l.rotation = 0.0
	# 고개 — BEAT에 tilt_from에서 tilt_to로 떨군다(양수 = 숙임, 리그 좌표라 좌우 부호는 안 곱한다)
	var head: Node2D = actor["head"]
	if head != null:
		var drop: float = smoothstep(BEAT_AT, BEAT_AT + 0.3, _time)
		head.rotation = deg_to_rad(lerpf(float(actor["tilt_from"]), float(actor["tilt_to"]), drop))
	_apply_face(actor)
	# 땀방울은 스스로 사라진다 — 지워진 노드를 타입 변수에 넣으면 에러라 먼저 확인한다
	var sweat_ref: Variant = actor["sweat"]
	if sweat_ref != null:
		if not is_instance_valid(sweat_ref):
			actor["sweat"] = null
		elif head != null:
			var sweat: Node2D = sweat_ref
			var base: Vector2 = sweat.get_meta("base")
			var head_rest: Vector2 = actor["head_rest"]
			sweat.position = base + (head.position - head_rest)

func _update_ropes(tug_s: float) -> void:
	var taut: float = _pulse(tug_s, 0.08, 4.5)
	var sway: float = sin(_clock * 2.3) * 1.5
	if _rope_a != null:
		_rope_a.visible = not _police.is_empty() and not _first.is_empty()
		if _rope_a.visible:
			var a: Vector2 = _line_layer.to_local((_police["hand_l"] as Node2D).global_position)
			var b: Vector2 = _cuff_point(_first)
			var police_world: Vector3 = _police["world"]
			var thick: float = rope_thickness * cast_scale * _px_per_unit(police_world.z)
			_rope_a.set("tail_length", thick * 5.0)
			_rope_a.call("set_rope", a, b, a.distance_to(b) * rope_sag * (1.0 - 0.85 * taut) + sway, thick)
	if _rope_b != null:
		_rope_b.visible = not _first.is_empty() and not _second.is_empty()
		if _rope_b.visible:
			var a2: Vector2 = _cuff_point(_first)
			var b2: Vector2 = _cuff_point(_second)
			var second_world: Vector3 = _second["world"]
			var thick2: float = rope_thickness * cast_scale * _px_per_unit(second_world.z)
			var taut2: float = _pulse(tug_s - 0.08, 0.08, 4.5)
			_rope_b.call("set_rope", a2, b2, a2.distance_to(b2) * rope_sag * (1.0 - 0.85 * taut2) - sway * 0.6, thick2)

## 수갑 찬 두 손목의 가운데(밧줄이 감기는 곳)
func _cuff_point(actor: Dictionary) -> Vector2:
	var cuffs: Node2D = actor["cuffs"]
	var rig: BodyRig = actor["rig"]
	if cuffs != null and is_instance_valid(cuffs):
		var local: Vector2 = cuffs.call("center")
		return _line_layer.to_local(rig.to_global(local))
	return _line_layer.to_local(rig.global_position)

func _update_building() -> void:
	var z: float = _building_world.z
	var k: float = _building_scale * z / maxf(z - _dolly, 0.05)
	_building.scale = Vector2(k, k)
	_building.position = _project(_building_world) - Vector2(0.0, _building_height * k)

# ---------------------------------------------------------------- 사건

## 구경꾼이 바라볼 곳(전역 좌표) — 패자·승자 머리 가운데. 행렬이 아직 없으면 문 앞
func _procession_center() -> Vector2:
	var points: Array = []
	for actor in [_first, _second]:
		if not actor.is_empty():
			var head: Node2D = actor["head"]
			points.append(head.global_position if head != null else (actor["rig"] as Node2D).global_position)
	if points.is_empty():
		return _stage.to_global(Vector2(door_screen_x, facade_base_y - 60.0))
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()

## 경찰이 빈손(앞손 HandR — 뒷손은 밧줄)으로 쫓아온 아이 머리를 "툭". 손은 팔 없이 떠 있어서 손만 날아가도 게임처럼 보인다.
## 들어 올림(0.22초) → 내리침(0.06초) → 잠깐 얹고(0.1초) → 제자리(0.3초). 리그·_pose_hands가 잡은 뒤에 덮어쓴다
func _police_tap() -> void:
	if _police.is_empty() or not _playing:
		return
	var hand: Node2D = _police["hand_r"]
	if hand == null:
		return
	for kid in _kids:
		var t: float = _time - float(kid["tap_at"])
		if t < -0.3 or t > 0.4:
			continue
		var kid_node: Node2D = kid["node"]
		var contact: Vector2 = kid_node.call("tap_point_global")
		var px: float = _px_per_unit((_police["world"] as Vector3).z) * cast_scale
		var above: Vector2 = contact + Vector2(0.06, -0.3) * px
		var rest: Vector2 = hand.global_position
		var target: Vector2
		if t < -0.08:
			var u: float = smoothstep(-0.3, -0.08, t)
			target = rest.lerp(above, u)
		elif t < 0.0:
			target = above.lerp(contact, smoothstep(-0.08, 0.0, t))
		elif t < 0.1:
			target = contact + Vector2(0.0, 0.02 * px * sin(t / 0.1 * PI))
		else:
			target = contact.lerp(rest, smoothstep(0.1, 0.4, t))
		hand.global_position = target
		return

func _police_look_back() -> void:
	if not _police.is_empty():
		(_police["rig"] as BodyRig).play_lookback()

## 승자가 "어? 나도 잡혀가?" — 이긴 얼굴이 풀리고(얼굴은 _face_now()가 BEAT_AT부터 시무룩한 쪽으로 바꾼다) 식은땀 한 방울. 무승부면 둘 다
func _winner_deflates() -> void:
	var targets: Array = [_second]
	if bool(_info.get("is_draw", false)):
		targets.append(_first)
	for actor in targets:
		if actor.is_empty():
			continue
		var rig: BodyRig = actor["rig"]
		rig.play_squash(Vector2(0.9, 1.1))
		_add_sweat(actor)
	_crowd_layer.call("react")

func _add_sweat(actor: Dictionary) -> void:
	var head_rect: Rect2 = actor["head_rect"]
	if head_rect.size == Vector2.ZERO:
		return
	var sweat := SweatMark.new()
	sweat.size = head_rect.size.y * 0.085
	var base := Vector2(head_rect.position.x + head_rect.size.x * 0.2, head_rect.position.y + head_rect.size.y * 0.3)
	sweat.set_meta("base", base)
	sweat.position = base
	(actor["rig"] as Node2D).add_child(sweat)
	actor["sweat"] = sweat

func _tug_squash() -> void:
	for actor in [_first, _second]:
		if not actor.is_empty():
			(actor["rig"] as BodyRig).play_squash(Vector2(1.06, 0.94))

func _finish() -> void:
	if _sent_finished:
		return
	_sent_finished = true
	ResultSfx.fade_out(_siren, 0.8)
	_siren = null
	# 장면이 다 떴으니 미리 읽어 둔 리그에서 손을 놓는다(승리·패배 화면 7초 + 이 장면 3초 뒤라 읽기는 다 끝나 있다 — 기다리지 않는다)
	release_warm()
	finished.emit()

# ---------------------------------------------------------------- 건물 배경 · 구경꾼 무리 · 가이드

## 건물 그림을 고르고 **문을 기준으로** 원근에 맞춰 놓는다(ArrestBackdropConfig.gd 참고).
## 그림 밑변(땅선)이 화면 facade_base_y에, 문 가운데가 door_screen_x에 오고, 그 깊이에서 문 높이가 캐릭터 키 x door_height가 되게 배율을 정한다.
## 문 자리를 안 적은 그림은 "원근 가이드 위에 화면 그대로 그린 그림"으로 보고 1280x720 화면에 1:1로 깐다
func _apply_backdrop(config: Resource) -> void:
	if config == null or config.get("texture") == null:
		return
	var tex: Texture2D = config.get("texture")
	var size: Vector2 = tex.get_size()
	var door: Rect2 = config.get("door_rect")
	var ground: float = float(config.get("ground_px"))
	if ground <= 0.0:
		# 문 자리 없이 원근 가이드 위에 그린 그림이면 땅선도 가이드의 초록 선(facade_base_y)이다
		ground = facade_base_y * size.x / BASE_SIZE.x if door.size.y <= 0.0 else size.y
	_building.texture = tex
	_building.region_enabled = true
	_building.region_rect = Rect2(0.0, 0.0, size.x, ground)
	_building_height = ground
	var base_y: float = facade_base_y
	var left_x: float = 0.0
	if door.size.y > 0.0:
		var z: float = _depth_of(base_y)
		_building_scale = float(config.get("door_height")) * focal / z / door.size.y
		left_x = door_screen_x - (door.position.x + door.size.x * 0.5) * _building_scale
		var horizon_px: float = float(config.get("horizon_px"))
		if horizon_px >= 0.0:
			var drawn_horizon: float = base_y - (ground - horizon_px) * _building_scale
			if absf(drawn_horizon - horizon_y) > 25.0:
				push_warning("ArrestScene: 배경 그림 눈높이가 장면 지평선과 %dpx 어긋난다 — 원근가이드.png에 맞춰 그림을 고칠 것" % int(drawn_horizon - horizon_y))
	else:
		_building_scale = BASE_SIZE.x / size.x
		base_y = ground * _building_scale
	var base_z: float = _depth_of(base_y)
	_building_world = Vector3((left_x - vanish_x) * base_z / focal, 0.0, base_z)
	_building.material = _edge_material if bool(config.get("edge_fade")) else null
	for flag in _building.get_children():
		if flag is CanvasItem:
			(flag as CanvasItem).visible = bool(config.get("show_flags"))
	_building.self_modulate.a = 0.45 if show_perspective_guide else 1.0
	_set_night(bool(config.get("night")), bool(config.get("night_moon")))
	_apply_lighting(config)
	_update_building()

## 밤 배경으로 바꾸거나 되돌린다 — 하늘(ArrestBackdrop)과, 하늘빛 안개에 녹던 얼굴 없는 무리의 공기색.
## 인물(경찰·두 사람·구경꾼 그림)은 **안 어둡게** 한다 — 가게 불빛 앞 길이라 잘 보여야 한다
func _set_night(on: bool, moon: bool) -> void:
	_backdrop.call("set_night", on, moon)
	var haze: Color = _backdrop.get("night_haze") if on else _day_haze
	for layer_node in [_mob_back, _mob_front]:
		if layer_node != null:
			layer_node.set("haze", haze)
	_crowd_layer.call("set_mob_haze", haze)

## 얼굴 없는 구경꾼 무리 — 구경꾼(crowd_feet)보다 먼 줄은 그 뒤에, 가까운 줄은 그 앞에 그려지게 두 겹으로 나눈다
func _build_mobs() -> void:
	_mob_back = _make_mob_layer(mob_back_feet, 11)
	_day_haze = _mob_back.get("haze")
	_stage.move_child(_mob_back, _crowd_layer.get_index())
	_mob_front = _make_mob_layer(mob_front_feet, 23)
	_stage.move_child(_mob_front, _line_layer.get_index())

## 동네 사람 구경꾼 — crowd_feet 자리마다 그림 한 장(없으면 얼굴 없는 사람). 판마다 같은 모습(같은 seed)
func _build_onlookers() -> void:
	var worlds: Array = []
	for feet in crowd_feet:
		worlds.append(_ground_to_world(feet))
	_crowd_layer.set("mob_shade", mob_shade)
	_crowd_layer.call("setup", worlds, onlooker_textures, onlooker_flip, onlooker_sizes, onlooker_height, 5, onlooker_scenes)

func _make_mob_layer(feet_list: Array[Vector2], seed_value: int) -> Node2D:
	var layer_node := Node2D.new()
	layer_node.set_script(MobScript)
	_stage.add_child(layer_node)
	var worlds: Array = []
	for feet in feet_list:
		worlds.append(_ground_to_world(feet))
	layer_node.set("shade", mob_shade)
	layer_node.call("setup", worlds, seed_value)
	return layer_node

# ---------------------------------------------------------------- 조명

## 빛 층 두 장(건물 바로 위 / 사람 위)과 인물 윤곽광 재질을 만든다
func _build_lighting() -> void:
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = LIGHT_SHADER
	_ground_light = Node2D.new()
	_ground_light.set_script(LightingScript)
	_ground_light.name = "GroundLight"
	_stage.add_child(_ground_light)
	_stage.move_child(_ground_light, _building.get_index() + 1)
	# 그늘을 먼저 곱하고 그 위에 빛을 더한다 — 건물 바로 다음(GroundLight 앞)
	_shade_light = Node2D.new()
	_shade_light.set_script(LightingScript)
	_shade_light.name = "ShadeLight"
	_shade_light.set("mode", 3)
	_stage.add_child(_shade_light)
	_stage.move_child(_shade_light, _building.get_index() + 1)
	_air_light = Node2D.new()
	_air_light.set_script(LightingScript)
	_air_light.name = "AirLight"
	_air_light.set("mode", 1)
	_air_light.z_index = AIR_LIGHT_Z
	_stage.add_child(_air_light)
	# 가장자리 어둡기는 번짐 밑 — 경광등 번짐까지 어두워지면 안 된다
	_vignette = Node2D.new()
	_vignette.set_script(LightingScript)
	_vignette.name = "Vignette"
	_vignette.set("mode", 2)
	_vignette.z_index = AIR_LIGHT_Z - 1
	_stage.add_child(_vignette)

## 맵 설정(ArrestBackdropConfig 조명 묶음)을 빛 층·사람 층·윤곽광에 넣는다
func _apply_lighting(config: Resource) -> void:
	for light in [_ground_light, _shade_light, _air_light, _vignette]:
		light.call("configure", config)
	# 밤이면 사람·차·구경꾼을 어둡게 — 윤곽광은 셰이더가 그 위에 더해서 어둠 속에서도 빛난다
	var ambient: Color = config.get("ambient")
	for layer_node in [_line_layer, _crowd_layer, _mob_back, _mob_front, _car]:
		if layer_node != null:
			layer_node.modulate = ambient
	_backdrop.set("night_ground_tint", float(config.get("ground_tint")))
	_siren_power = float(config.get("siren_power"))
	_light_mat.set_shader_parameter("light_dir", config.get("rim_dir"))
	_light_mat.set_shader_parameter("rim_color", config.get("rim_color"))
	_light_mat.set_shader_parameter("rim_strength", float(config.get("rim_strength")))
	_light_mat.set_shader_parameter("rim_focus", float(config.get("rim_focus")))
	_light_mat.set_shader_parameter("rim_px", float(config.get("rim_px")))
	_light_mat.set_shader_parameter("shade_strength", float(config.get("shade_strength")))
	_light_mat.set_shader_parameter("gradient_strength", float(config.get("gradient_strength")))
## 인물 그림 조각(Sprite2D)에 윤곽광 재질을 붙인다 — 스크립트가 달린 표시와 이미 다른 재질이 있는 조각은 건드리지 않는다
## (게임의 `BodyRig.set_rim_light()`와 같은 규칙)
func _light_parts(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.get_script() == null and child.material == null:
			(child as Sprite2D).material = _light_mat
		_light_parts(child)

## 빛 층에 카메라·건물 자리·경광등을 넣고, 경광등이 번쩍이면 인물 윤곽광에 그 색을 싣는다
func _update_lighting() -> void:
	if _ground_light == null:
		return
	var state: Dictionary = _car.call("light_state")
	var rect: Rect2 = get_viewport().get_visible_rect()
	var view := Rect2(rect.position - _stage.position, rect.size)
	for light in [_ground_light, _shade_light, _air_light, _vignette]:
		light.set("building_width", _building.region_rect.size.x)
		light.set("vanish_x", vanish_x)
		light.set("horizon_y", horizon_y)
		light.set("camera_height", camera_height)
		light.set("focal", focal)
		light.set("dolly", _dolly)
		light.set("building_pos", _building.position)
		light.set("building_scale", _building.scale.x)
		light.set("building_ground_px", _building_height)
		light.set("building_z", _building_world.z)
		light.set("view_rect", view)
		light.set("siren", state)
	var strength: float = 0.0
	var color: Color = state.get("red_color", Color.RED)
	if bool(state.get("red_on", false)):
		strength = 1.0
	elif bool(state.get("blue_on", false)):
		color = state.get("blue_color", Color.BLUE)
		strength = 1.0
	# 빛은 경찰차 등에서 행렬 쪽으로 온다 — 인물 → 등 방향
	var dir := Vector2(-1.0, -0.4)
	if not _police.is_empty():
		var to_car: Vector2 = (state.get("red", Vector2.ZERO) as Vector2) - _project(_police["world"])
		if to_car.length() > 1.0:
			dir = to_car.normalized()
	_light_mat.set_shader_parameter("siren_dir", dir)
	_light_mat.set_shader_parameter("siren_color", color)
	_light_mat.set_shader_parameter("siren_strength", strength * _siren_power * 1.6)

## 가이드에 지금 카메라·문 자리·키 막대 자리를 넣는다
func _update_guide() -> void:
	if _guide == null:
		return
	_guide.set("vanish_x", vanish_x)
	_guide.set("horizon_y", horizon_y)
	_guide.set("camera_height", camera_height)
	_guide.set("focal", focal)
	_guide.set("facade_base_y", facade_base_y)
	_guide.set("door_screen_x", door_screen_x)
	var config: Resource = default_backdrop if default_backdrop != null else load(DEFAULT_BACKDROP)
	_guide.set("door_height", float(config.get("door_height")) if config != null else 1.35)
	var rect: Rect2 = get_viewport().get_visible_rect()
	_guide.set("view_rect", Rect2(rect.position - _stage.position, rect.size))
	var markers: Array = [["경찰", police_feet], ["패자", first_feet], ["승자", second_feet]]
	if not crowd_feet.is_empty():
		markers.append(["구경꾼", crowd_feet[0]])
	if not mob_back_feet.is_empty():
		markers.append(["먼 구경꾼", mob_back_feet[mob_back_feet.size() - 1]])
	_guide.set("markers", markers)
	_guide.queue_redraw()

# ---------------------------------------------------------------- 원근 계산

## 바닥 높이(화면 y)에 있는 점의 깊이
func _depth_of(screen_y: float) -> float:
	return focal * camera_height / maxf(screen_y - horizon_y, 1.0)

## 밀고 들어가기 전 화면의 발 위치 -> 월드(X, 0, Z)
func _ground_to_world(feet: Vector2) -> Vector3:
	var z: float = _depth_of(feet.y)
	return Vector3((feet.x - vanish_x) * z / focal, 0.0, z)

## 월드 -> 화면(Stage 좌표). Y는 위가 +
func _project(p: Vector3) -> Vector2:
	var z: float = maxf(p.z - _dolly, 0.05)
	return Vector2(vanish_x + focal * p.x / z, horizon_y + focal * (camera_height - p.y) / z)

## 깊이 z에서 키 1이 화면에서 몇 px인지
func _px_per_unit(z: float) -> float:
	return focal / maxf(z - _dolly, 0.05)

## 걸음 진행도(0~1) — 두 구간에 나눠 걷고, 구간마다 천천히 출발해 천천히 선다
func _walk_progress(t: float) -> float:
	if t <= WALK_1.x:
		return 0.0
	if t < WALK_1.y:
		return WALK_SPLIT * _ease_walk((t - WALK_1.x) / (WALK_1.y - WALK_1.x))
	if t <= WALK_2.x:
		return WALK_SPLIT
	if t < WALK_2.y:
		return WALK_SPLIT + (1.0 - WALK_SPLIT) * _ease_walk((t - WALK_2.x) / (WALK_2.y - WALK_2.x))
	return 1.0

## 사다리꼴 속도(앞뒤 18%만 가속·감속) — 대부분 같은 빠르기라 발걸음과 잘 맞는다
static func _ease_walk(u: float) -> float:
	var a: float = 0.18
	u = clampf(u, 0.0, 1.0)
	var norm: float = 1.0 - a
	if u < a:
		return u * u / (2.0 * a * norm)
	if u < 1.0 - a:
		return (u - a * 0.5) / norm
	return 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * a * norm)

## 확 올라갔다 서서히 잦아드는 한 번의 출렁임(s < 0이면 0)
static func _pulse(s: float, rise: float, decay: float) -> float:
	if s < 0.0:
		return 0.0
	if s < rise:
		return sin(s / rise * PI * 0.5)
	return exp(-(s - rise) * decay)

# ---------------------------------------------------------------- 리그 크기 재기

## [보이는 영역, 머리 영역](리그 좌표) — **실제로 칠해진 부분**만 잰다(그림 여백은 캐릭터마다 달라서)
func _measure(rig: Node2D, path: String) -> Array:
	if _bounds_cache.has(path):
		return _bounds_cache[path]
	var to_rig: Transform2D = rig.get_global_transform().affine_inverse()
	var bounds := Rect2()
	var started: bool = false
	var head_rect := Rect2()
	for sprite in _sprites_of(rig):
		if sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var r: Rect2 = _rect_in(to_rig * sprite.get_global_transform(), _opaque_local(sprite))
		if not started:
			bounds = r
			started = true
		else:
			bounds = bounds.merge(r)
		if sprite.name == &"Head" and sprite.get_parent() == rig:
			head_rect = r
	var out: Array = [bounds, head_rect]
	_bounds_cache[path] = out
	return out

static func _rect_in(xf: Transform2D, r: Rect2) -> Rect2:
	var out := Rect2(xf * r.position, Vector2.ZERO)
	for corner in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out = out.expand(xf * corner)
	return out

static func _sprites_of(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	if node is Sprite2D:
		found.append(node as Sprite2D)
	for child in node.get_children():
		found.append_array(_sprites_of(child))
	return found

## 스프라이트 자기 좌표에서 칠해진 영역
static func _opaque_local(sprite: Sprite2D) -> Rect2:
	var full: Rect2 = sprite.get_rect()
	if sprite.region_enabled or sprite.hframes > 1 or sprite.vframes > 1:
		return full
	var o: Rect2 = _opaque_rect(sprite.texture)
	var x: float = full.size.x - o.position.x - o.size.x if sprite.flip_h else o.position.x
	var y: float = full.size.y - o.position.y - o.size.y if sprite.flip_v else o.position.y
	return Rect2(full.position + Vector2(x, y), o.size)

## 그림에서 반쯤 이상 불투명한 영역. 작게 줄여서 잰다(큰 그림을 한 점씩 보면 첫 프레임이 끊긴다)
static func _opaque_rect(tex: Texture2D) -> Rect2:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var size: Vector2 = tex.get_size()
	var rect := Rect2(Vector2.ZERO, size)
	var img: Image = tex.get_image()
	if img != null and size.x > 0.0 and size.y > 0.0:
		if img.is_compressed():
			img.decompress()
		var shrink: float = minf(1.0, 128.0 / maxf(size.x, size.y))
		var w: int = maxi(int(round(size.x * shrink)), 1)
		var h: int = maxi(int(round(size.y * shrink)), 1)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var min_p := Vector2i(w, h)
		var max_p := Vector2i(-1, -1)
		for yy in h:
			for xx in w:
				if img.get_pixel(xx, yy).a >= 0.5:
					min_p = Vector2i(mini(min_p.x, xx), mini(min_p.y, yy))
					max_p = Vector2i(maxi(max_p.x, xx), maxi(max_p.y, yy))
		if max_p.x >= 0:
			var sx: float = size.x / w
			var sy: float = size.y / h
			rect = Rect2(min_p.x * sx, min_p.y * sy, (max_p.x - min_p.x + 1) * sx, (max_p.y - min_p.y + 1) * sy)
	_opaque_cache[key] = rect
	return rect

# ---------------------------------------------------------------- 작은 그림들

## 발밑 그림자 — 멀수록 납작해진다(바닥 원을 비스듬히 본 모양)
class ShadowBlob extends Node2D:
	var radius: Vector2 = Vector2.ZERO
	var color: Color = Color(0.16, 0.11, 0.09, 0.27)

	## 반지름이 바뀌었을 때만 다시 그린다
	func set_radius(r: Vector2) -> void:
		if r.is_equal_approx(radius):
			return
		radius = r
		queue_redraw()

	func _draw() -> void:
		if radius.x < 0.5 or radius.y < 0.3:
			return
		var pts := PackedVector2Array()
		for i in 28:
			var t: float = TAU * i / 28.0
			pts.append(Vector2(radius.x * 0.08 + cos(t) * radius.x, sin(t) * radius.y))
		draw_colored_polygon(pts, color)

## 수갑 — 두 손목에 쇠고리 + 가운데 짧은 사슬. 리그의 자식이라 리그 좌표로 그린다
class Cuffs extends Node2D:
	var hand_l: Node2D = null
	var hand_r: Node2D = null
	## 손 그림 가운데에서 손목(몸 쪽)까지
	var back: float = 5.5
	var ring_size: Vector2 = Vector2(2.2, 5.4)
	var steel: Color = Color(0.8, 0.83, 0.88)
	var shine: Color = Color(1, 1, 1, 0.9)
	var line: Color = Color(0.07, 0.07, 0.09)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _wrist(hand: Node2D) -> Vector2:
		return hand.position + Vector2(-back, 1.2)

	## 두 손목의 가운데 — 밧줄이 여기 감긴다
	func center() -> Vector2:
		if hand_l == null or hand_r == null:
			return position
		return (_wrist(hand_l) + _wrist(hand_r)) * 0.5

	func _draw() -> void:
		if hand_l == null or hand_r == null:
			return
		var a: Vector2 = _wrist(hand_l)
		var b: Vector2 = _wrist(hand_r)
		for i in range(1, 3):
			var p: Vector2 = a.lerp(b, i / 3.0) + Vector2(0.0, ring_size.y * 0.3)
			draw_circle(p, ring_size.x * 0.75, line)
			draw_circle(p, ring_size.x * 0.42, steel)
		_ring(a)
		_ring(b)

	func _ring(c: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in 21:
			var t: float = TAU * i / 20.0
			pts.append(c + Vector2(cos(t) * ring_size.x, sin(t) * ring_size.y))
		draw_polyline(pts, line, ring_size.x * 0.95, true)
		draw_polyline(pts, steel, ring_size.x * 0.45, true)
		draw_polyline(pts.slice(12, 16), shine, ring_size.x * 0.22, true)

## 식은땀 한 방울(만화 기호) — 나타나서 조금 흘러내리다 사라진다. 리그 좌표로 그린다
class SweatMark extends Node2D:
	var size: float = 4.0
	var life: float = 2.4
	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += minf(delta, 0.05)
		queue_redraw()
		if _age >= life:
			queue_free()

	func _draw() -> void:
		var pop: float = clampf(_age / 0.12, 0.0, 1.0)
		var fade: float = 1.0 - clampf((_age - (life - 0.5)) / 0.5, 0.0, 1.0)
		var s: float = size * (0.55 + 0.45 * pop)
		var drop := Vector2(0.0, size * 0.9 * clampf(_age / life, 0.0, 1.0))
		var pts := PackedVector2Array([drop + Vector2(0.0, -s * 2.2)])
		for i in 15:
			var deg: float = lerpf(-35.0, 215.0, i / 14.0)
			pts.append(drop + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * s)
		draw_colored_polygon(pts, Color(0.62, 0.86, 1.0, fade))
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0.08, 0.13, 0.24, fade), maxf(s * 0.22, 0.6), true)
		draw_circle(drop + Vector2(-s * 0.35, -s * 0.15), s * 0.26, Color(1, 1, 1, 0.9 * fade))
