@tool
class_name SlowPan
extends Control

## **세로로 긴 그림을 천천히 훑는 연출** — 지하철 아저씨 편(2026-10-11 사용자 구상:
## "거만하게 앉아있는 지하철 아저씨의 모습을 아래서부터 위로 보여줌").
##
## 그림을 **화면 폭에 꽉 차게** 키운 뒤(세로는 화면 밖으로 넘친다) 위아래로 민다.
## `from_bottom`을 켜면 발밑에서 시작해 얼굴로 올라가고, 끄면 반대로 내려온다.
##
## 세로 그림(1140x1380 같은)을 16:9에 그냥 넣으면 좌우가 횡하게 비는데,
## 폭을 채우고 세로를 훑으면 **비는 데 없이** 그림을 다 보여줄 수 있다.

## 훑을 그림
@export var texture: Texture2D = null:
	set(value):
		texture = value
		_lay_out()
## **아래에서 위로** 훑을지. 끄면 위에서 아래로
@export var from_bottom: bool = true:
	set(value):
		from_bottom = value
		_lay_out()
## 훑기 시작하는 때(초)와 걸리는 시간(초).
## **`pan_time`을 0으로 두면 안 움직이고 시작 자리에 그대로 멈춰 있는다** — 세로로 긴 그림을
## 위(얼굴) 또는 아래(발)에 맞춰 세워 두고 싶을 때 쓴다. `TextureRect`의 COVERED는 늘 가운데를
## 보여줘서 인물 그림이면 얼굴이 잘려 나간다(2026-10-11 경찰 그림에서 겪음)
@export var pan_at: float = 0.0
@export var pan_time: float = 2.2
## 그림을 화면 폭보다 얼마나 더 키울지(1이면 폭에 딱 맞춘다).
## 1보다 크게 주면 좌우가 조금 잘리는 대신 인물이 커진다
@export var zoom: float = 1.0:
	set(value):
		zoom = value
		_lay_out()
## 끝에서 **멈춰 있는** 자리를 조금 비킨다(px, 음수면 더 위로).
## 얼굴이 화면 맨 위에 딱 붙어 답답하면 여기로 내린다
@export var end_offset: float = 0.0:
	set(value):
		end_offset = value
		_lay_out()
## 에디터에서 끝난 모습 그대로 보여준다 — 값을 보며 맞추려고
@export var preview_end: bool = false:
	set(value):
		preview_end = value
		_lay_out()

var _image: TextureRect = null
var _t: float = 0.0
var _running: bool = false

func _ready() -> void:
	_build()
	_lay_out()
	if not Engine.is_editor_hint():
		_apply(0.0)
		# **장면이 열리면 알아서 훑기 시작한다** — StoryFadeScene에는 이걸 불러 줄 자리가 없고,
		# 훑기는 장면이 뜨는 것과 동시에 시작하는 게 맞다(대사는 `@pause`로 기다린다)
		play()

func _build() -> void:
	if _image != null and is_instance_valid(_image):
		return
	_image = TextureRect.new()
	_image.name = "Image"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 폭을 채우고 세로로 넘치게 둔다 — 잘라내지 않고 그대로 민다
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_image)

## 그림을 화면 폭에 맞춰 키우고, 넘치는 세로 길이를 재 둔다
func _lay_out() -> void:
	if _image == null or not is_instance_valid(_image):
		_build()
	if _image == null or texture == null:
		return
	_image.texture = texture
	var view: Vector2 = _screen()
	var width: float = view.x * maxf(zoom, 0.01)
	var height: float = width * texture.get_size().y / maxf(texture.get_size().x, 1.0)
	_image.size = Vector2(width, height)
	_image.position.x = (view.x - width) * 0.5
	_apply(1.0 if (Engine.is_editor_hint() and preview_end) else 0.0)

## ⚠️ **트리에 붙기 전에도 불린다** — @export setter가 씬을 읽는 도중 `_lay_out()`을 부르는데
## 그때는 아직 뷰포트가 없어서 `get_viewport_rect()`가 에러를 낸다. 기본 크기로 버티고,
## `_ready`에서 다시 재면 제 크기로 맞는다
func _screen() -> Vector2:
	if not is_inside_tree():
		return Vector2(1920, 1080)
	var rect: Rect2 = get_viewport_rect()
	return rect.size if rect.size.x > 1.0 else Vector2(1920, 1080)

## 넘치는 세로 길이 — 이만큼 밀 수 있다
func _slack() -> float:
	if _image == null or texture == null:
		return 0.0
	return maxf(_image.size.y - _screen().y, 0.0)

## u가 0이면 시작 자리, 1이면 끝 자리
func _apply(u: float) -> void:
	if _image == null or not is_instance_valid(_image):
		return
	var slack: float = _slack()
	# 아래에서 위로 = 그림을 위로 당긴다(y가 -slack에서 0으로)
	var start_y: float = -slack if from_bottom else 0.0
	var end_y: float = 0.0 if from_bottom else -slack
	_image.position.y = lerpf(start_y, end_y, u) + end_offset * u

func play() -> void:
	_t = 0.0
	_running = true
	_apply(0.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _running:
		return
	if pan_time <= 0.0:
		_running = false   # 안 움직이는 모드 — 시작 자리에 그대로 둔다
		return
	_t += delta
	if _t < pan_at:
		return
	var u: float = clampf((_t - pan_at) / maxf(pan_time, 0.001), 0.0, 1.0)
	# 천천히 시작해 천천히 멈춘다 — 훑는 눈길처럼
	u = u * u * (3.0 - 2.0 * u)
	_apply(u)
	if _t >= pan_at + pan_time:
		_running = false
