extends Node2D

## 층간소음 빌런이 이긴 **승리 화면에만** 나오는 아이(2026-10-11 팀 피드백: "화면 밖에 있다가 띠용 하면서 나오는 느낌").
## 화면 밑에 숨어 있다가 용수철처럼 튀어 올라 한 번 넘치고 출렁이며 서고, 그 뒤로 엄마 옆에서 방방 뛴다.
##  - 그림은 게임 속 아이(`Kid.tscn`)를 그대로 쓰고 **얼굴만 활짝 웃는 정면 얼굴**로 바꾼다
##  - 자세는 달려가는 아이(`RunningKid`)와 같은 땅(land) ↔ 꼭대기(peak) 자세 씬을 섞는다
##  - 크기·자리는 화면 비율로 잡는다 — `MatchEnding`이 `setup()` → `layout()` → 매 프레임 `tick()`을 부른다(실제 시간)
##  - 그리는 순서: 씬에서 `z_index` 6 — 앞 색종이(0)와 엄마 손(층간소음 오른손이 z 3)보다 **앞**,
##    승리 글자(Title, z 7)보다 **뒤**. 노드 순서만으로는 z 3짜리 엄마 손이 아이 얼굴을 덮었다(실측)
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — 쓰는 쪽은 노드로 부른다

const ResultSfx = preload("res://ui/result/ResultSfx.gd")
## 띠용 소리 이름 — `Sound/result/boing.ogg|wav|mp3`를 넣으면 나온다(없으면 조용히 넘어간다)
const BOING := "boing"

## 이 캐릭터가 이겼을 때만 나온다(GameState.CHARACTERS 이름). F6 미리보기처럼 이름이 없으면 리그 경로로도 알아본다
@export var for_character: String = "층간소음 빌런"
@export_file("*.tscn") var for_rig: String = "res://characters/floornoise/FloorNoiseRig.tscn"
@export var kid_scene: PackedScene = preload("res://characters/floornoise/Kid.tscn")
## 얼굴을 이 그림으로 바꾼다(비우면 게임 속 옆얼굴 그대로). 원래 머리와 **같은 캔버스(1374x1145)** 라 배율을 그대로 쓴다
@export var face_texture: Texture2D = preload("res://sprite/층간소음/입벌린아이정면.png")
@export var land_pose: PackedScene = preload("res://characters/floornoise/KidLandPose.tscn")
@export var peak_pose: PackedScene = preload("res://characters/floornoise/KidPeakPose.tscn")

@export_group("크기·자리")
## 아이 키(머리 꼭대기 ~ 발끝) / 화면 높이
@export var height_ratio: float = 0.38
## 아이 가운데 x — 엄마 쪽 화면 끝에서 잰 거리 / 화면 폭
@export var x_from_edge: float = 0.555
## 발 딛는 땅 = 화면 맨 밑 + 화면 높이 x 이 값. 양수면 서 있을 때 발이 화면 밖으로 살짝 잘린다(엄마처럼)
@export var ground_below: float = 0.06
## 엄마 쪽을 보게 할지. 끄면 엄마와 같은 쪽을 본다
@export var face_parent: bool = false

@export_group("띠용")
## 승리 화면이 시작되고 몇 초 뒤에 튀어 나오는지(엄마가 자리 잡은 뒤)
@export var enter_at: float = 0.5
## 처음에 화면 밑으로 숨어 있는 깊이 / 아이 키 — 1보다 크면 머리까지 다 숨는다
@export var hide_depth: float = 1.15
## 용수철 — 한 번 넘쳤다 돌아오는 빠르기(라디안/초)와 자리가 잦아드는 빠르기(1/초)
@export var spring_freq: float = 15.0
@export var spring_damp: float = 7.0
## 늘어나고 눌리는 정도와 그 출렁임이 잦아드는 빠르기(1/초) — 자리보다 느리게 잦아들어야 "띠요옹" 하고 남는다
@export var wobble: float = 0.26
@export var wobble_damp: float = 3.6
## 튀어 나온 뒤 몇 초부터 방방 뛰기 시작하는지
@export var settle_time: float = 0.42

@export_group("방방")
## 한 번 뛰는 시간(초)
@export var hop_period: float = 0.36
## 뛰는 높이 / 화면 높이
@export var hop_height: float = 0.06
## 뛸 때마다 좌우로 기우는 각도(도)
@export var hop_sway_deg: float = 5.0

var _puppet: Node2D
var _kid: Node2D
## 아이 그림 전체 네모(Kid.tscn 좌표) — 크기를 화면 비율로 맞추는 기준
var _bounds: Rect2 = Rect2(-150, -155, 300, 295)
var _left: bool = true
var _facing: float = 1.0
var _fit: float = 1.0
var _base: Vector2 = Vector2.ZERO
var _vis: Rect2 = Rect2(0, 0, 1280, 720)
var _boinged: bool = false

func _ready() -> void:
	visible = false

## 이 승자에게 아이가 나와야 하는지
func wants(character_name: String, rig_path: String) -> bool:
	if kid_scene == null:
		return false
	return (for_character != "" and character_name == for_character) or (for_rig != "" and rig_path == for_rig)

## 아이를 만든다. left = 엄마가 화면 왼쪽인지, parent_facing = 엄마가 보는 쪽(1 오른쪽 / -1 왼쪽)
func setup(left: bool, parent_facing: float) -> void:
	if _kid != null or kid_scene == null:
		return
	_left = left
	_facing = -parent_facing if face_parent else parent_facing
	_puppet = Node2D.new()
	add_child(_puppet)
	_kid = kid_scene.instantiate() as Node2D
	if _kid == null:
		return
	var head := _kid.get_node_or_null("KidHead") as Sprite2D
	if head != null and face_texture != null:
		head.texture = face_texture
	_bounds = _measure(_kid)
	# 발바닥 가운데가 인형(Puppet) 원점에 오게 — 눌렸다 늘어날 때 발밑을 축으로 삼는다
	_kid.position = -Vector2(_bounds.get_center().x, _bounds.end.y)
	_puppet.add_child(_kid)

## 화면 크기에 맞춰 크기·자리를 다시 잡는다. parent_x/parent_radius = 엄마 머리 가운데 x와 반지름(화면 px, 모르면 음수).
## ⚠️ 자리는 화면 **폭** 비율인데 엄마 크기는 화면 **높이**를 따라간다 — 16:10·4:3처럼 좁은 화면에선 엄마 머리가 상대적으로 넓어져
## 아이가 엄마 턱에 올라탄다(검수 지적). 그래서 엄마 머리 밖으로는 꼭 밀어낸다
func layout(vis: Rect2, parent_x: float = -1.0, parent_radius: float = -1.0) -> void:
	_vis = vis
	_fit = height_ratio * vis.size.y / maxf(_bounds.size.y, 1.0)
	var x: float = vis.position.x + vis.size.x * x_from_edge if _left else vis.end.x - vis.size.x * x_from_edge
	if parent_radius > 0.0:
		var clear: float = parent_radius + _bounds.size.x * 0.5 * _fit * 0.6
		x = maxf(x, parent_x + clear) if _left else minf(x, parent_x - clear)
	_base = Vector2(x, vis.end.y + vis.size.y * ground_below)

## t = 승리 화면이 시작되고 흐른 실제 초
func tick(_dt: float, t: float) -> void:
	if _kid == null:
		return
	var tau: float = t - enter_at
	if tau < 0.0:
		visible = false
		return
	visible = true
	if not _boinged:
		_boinged = true
		ResultSfx.play(self, BOING, -3.0)
	var kid_h: float = _bounds.size.y * _fit
	# 띠용 — 자리는 용수철: 밑에서 튀어 올라 한 번 넘치고 돌아와 선다
	var amp: float = hide_depth * kid_h
	var w: float = spring_freq * tau
	var y_off: float = amp * exp(-spring_damp * tau) * cos(w)
	# 몸은 그 용수철이 움직이는 쪽으로 늘어난다(올라갈 땐 길쭉, 내려앉을 땐 납작). 자리보다 늦게 잦아들어 출렁임이 남는다
	var stretch: float = exp(-wobble_damp * tau) * (sin(w) + spring_damp / maxf(spring_freq, 0.01) * cos(w))
	var sy: float = 1.0 + wobble * stretch
	var sx: float = 1.0 - wobble * 0.6 * stretch
	# 방방 — 땅에 닿을 때 눌리고 떠오르며 늘어난다(엄마의 통통과 같은 모양, 더 빠르고 높게)
	var ht: float = maxf(tau - settle_time, 0.0)
	var hw: float = clampf(ht / 0.12, 0.0, 1.0)
	var p: float = fmod(ht / maxf(hop_period, 0.05), 1.0)
	var height: float = sin(p * PI) * hw
	var contact: float = maxf(0.0, 1.0 - minf(p, 1.0 - p) / 0.16) * hw
	sx *= 1.0 + 0.1 * contact - 0.04 * height
	sy *= 1.0 - 0.13 * contact + 0.07 * height
	position = _base + Vector2(0.0, y_off - height * hop_height * _vis.size.y)
	rotation = sin(ht * PI / maxf(hop_period, 0.05)) * deg_to_rad(hop_sway_deg) * hw * _facing
	_puppet.scale = Vector2(_fit * _facing * sx, _fit * sy)
	# 자세 — 늘어나며 솟구칠 때·떠 있을 때는 만세(꼭대기), 닿을 때는 무릎 굽힌 착지
	var high: float = maxf(clampf(stretch * 1.8, 0.0, 1.0), height)
	_put_pose(land_pose, 1.0)
	_put_pose(peak_pose, high)

## 자세 씬 하나를 weight만큼 섞는다(RunningKid와 같은 방법 — 조각은 이름으로 찾는다)
func _put_pose(scene: PackedScene, weight: float) -> void:
	if scene == null or weight <= 0.0:
		return
	var pose: Dictionary = BodyRig.read_pose(scene)
	for part_name in pose:
		var part := _kid.get_node_or_null(NodePath(part_name)) as Node2D
		if part == null:
			continue
		var data: Array = pose[part_name]
		part.position = part.position.lerp(data[0] as Vector2, weight)
		part.rotation = lerp_angle(part.rotation, data[1] as float, weight)

## 아이 그림 조각을 다 감싸는 네모(아이 루트 좌표)
static func _measure(kid: Node2D) -> Rect2:
	var out := Rect2()
	var found: bool = false
	for child in kid.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var xf: Transform2D = sprite.transform
		var r: Rect2 = sprite.get_rect()
		var box := Rect2(xf * r.position, Vector2.ZERO)
		for corner in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			box = box.expand(xf * corner)
		out = box if not found else out.merge(box)
		found = true
	return out if found else Rect2(-150, -155, 300, 295)
