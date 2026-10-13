class_name Sfx
extends RefCounted

## 효과음 한 번 울리기 — 어디서든 `Sfx.play(self, 소리)` 한 줄로 쓴다.
## 소리 노드를 **지금 장면 루트**에 붙여서, 부른 노드(판정·투사체)가 먼저 사라져도 소리가 끝까지 난다.
## 버스는 "Sfx"라 설정의 효과음 볼륨을 따른다. 다 울리면 스스로 지워진다
##
## **소리가 난 자리에 따라 좌우로 갈린다**(2026-10-13 사용자 "위치에 따라 좌우") — 부른 노드(또는 그 위의 가장 가까운 Node2D)
## 자리에 `AudioStreamPlayer2D`를 놓는다. 화면 왼쪽에서 난 소리는 왼쪽 스피커로 더 간다.
## 멀어져도 작아지지는 않게 거리 감쇠는 끈다(크기는 파일·volume_db 그대로). 자리를 못 찾으면 예전처럼 가운데서 난다

## 같은 소리가 기계처럼 똑같이 들리지 않게 매번 음높이를 이만큼 흔든다(±)
const DEFAULT_PITCH_JITTER: float = 0.08
## 좌우로 갈리는 세기(0 = 가운데, 1 = 프로젝트 기본). 끝까지 한쪽으로 쏠리면 어색해서 조금 덜어 낸다
const PANNING_STRENGTH: float = 0.8

## ── 소리 크기 표 (2026-10-13 전체 맞춤) ──────────────────────────────────────────────
## 파일마다 녹음 크기가 제각각이라(가장 큰 것과 작은 것이 33dB 차이) **실측해서 한 곳에서 맞춘다.**
## 재는 법: 게임에서 실제로 쓰는 구간만 틀어 녹음 → 소리가 나는 동안의 평균 크기(가장 큰 50ms의 1% 밑은 무음으로 빼고).
## 그 값을 **소리 종류별 목표**에 맞추는 만큼 더하거나 뺀다. 단 가장 센 순간이 -1dB를 넘지 않게(찢어지지 않게) 자른다.
##
##   큰 순간 -13  : 3타·카운터·궁극기·벤 자국·부딪힘·깨짐·부서짐 — 판이 갈리는 소리
##   기술     -16  : 펀치·패링·스킬 소리·회복 — 싸움의 바탕
##   잦은 것  -19  : 고양이 피격·스폰 — 자주 나서 한 단계 작게
##   움직임   -21  : 점프·대시·헛스윙·방어·망치질·자전거 바퀴/벨 — 계속 나는 소리라 뒤로
##   메뉴     -20  : 클릭
##
## 소리를 새로 넣거나 파일을 바꾸면 **다시 재서 이 표에 한 줄** 넣을 것(없으면 0 = 파일 그대로).
## 표 값 위에 부르는 쪽의 volume_db가 더해진다 — 이 표를 쓰는 동안엔 부르는 쪽에서 따로 줄이지 말 것
const GAIN_DB := {
	"res://audio/click.mp3": -3.9,
	"res://audio/punch.mp3": -1.0,
	"res://audio/3타 펀치.mp3": -1.4,
	"res://audio/헛스윙.mp3": -1.1,
	"res://audio/헛스윙2.mp3": -5.8,
	"res://audio/대쉬.mp3": -1.1,
	"res://audio/점프.mp3": -10.4,
	"res://audio/방어 할 떄.mp3": -5.2,
	"res://audio/방어 패링.mp3": 11.6,
	"res://audio/카운터.mp3": -2.0,
	"res://audio/바닥,벽의 부디 침.mp3": -0.6,
	"res://audio/궁극기소리.mp3": 8.6,
	"res://audio/hp 회복.mp3": 6.9,
	"res://audio/금쪽이/금쪽이 자전거 바퀴 소리.mp3": 11.0,
	"res://audio/금쪽이/금쪽이 자전거 벨 소리.mp3": 16.8,
	"res://audio/금쪽이/금쪽이 자전거 부디칠 떄 소리.mp3": -0.5,
	"res://audio/금쪽이/금쪽이 총 소리.mp3": 3.7,
	"res://audio/주정뱅이/주정뱅이 궁극기.mp3": -5.0,
	"res://audio/주정뱅이/주정뱅이 술 마실 떄.mp3": -0.9,
	"res://audio/주정뱅이/주정뱅이 토.mp3": 2.2,
	"res://audio/주정뱅이/술병 깨 질 때.mp3": 3.3,
	"res://audio/악플러/악플러 마우스 던 질 때.mp3": -9.8,
	"res://audio/악플러/악플러 열등감.mp3": -3.1,
	"res://audio/악플러/악플러 회전 공격.mp3": 1.7,
	"res://audio/고양이 아줌마/고양이 공격.mp3": 1.0,
	"res://audio/고양이 아줌마/고양이 스폰 될 때.mp3": 5.4,
	"res://audio/고양이 아줌마/고양이 아줌마 집 다 지었다.mp3": 1.3,
	"res://audio/고양이 아줌마/고양이 아줌마 집 짓기.mp3": -8.8,
	"res://audio/고양이 아줌마/고양이 집 뿌서질 떄.mp3": -1.0,
	"res://audio/고양이 아줌마/고양이 피격.mp3": -1.7,
	"res://audio/고양이 아줌마/햐양 고양이 회복.mp3": -0.4,
	"res://audio/지하철 아저씨/지하철 아저씨 개찰구.mp3": -9.2,
	"res://audio/지하철 아저씨/지하철 아저씨 대쉬 배기.mp3": 5.2,
	"res://audio/지하철 아저씨/지하철 아저씨 반격기 쓸 때.mp3": 16.3,
	"res://audio/지하철 아저씨/지하철아저씨 벤 자국 터질 떄 .mp3": 0.5,
}

## 표에 적힌 이 소리의 크기 보정(dB). 없으면 0
static func gain_of(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	return float(GAIN_DB.get(stream.resource_path, 0.0))

## `stream`을 한 번 울린다. `pitch`는 기준 음높이(1 = 원래대로, 낮을수록 묵직하다).
## 틀고 있는 플레이어(AudioStreamPlayer2D 또는 AudioStreamPlayer)를 돌려준다(안 틀었으면 null) — 앞부분만 쓰고 끊을 때 쓴다.
## 둘 다 `seek`·`volume_db`·`pitch_scale`·`finished`가 같아서 받는 쪽은 타입 없이 쓰면 된다
static func play(from: Node, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = DEFAULT_PITCH_JITTER) -> Node:
	if stream == null or from == null or not from.is_inside_tree():
		return null
	# 타이틀 구경 모드(AI끼리 싸우는 배경)는 조용히 — 타이틀 음악 위로 점프·대시 소리가 깔리면 안 된다
	if GameState.game_mode == "attract":
		return null
	var root: Node = from.get_tree().current_scene
	if root == null:
		root = from.get_tree().root
	var spot: Node2D = _spot_of(from)
	var player   # AudioStreamPlayer2D 또는 AudioStreamPlayer
	if spot != null:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 100000.0
		p2.attenuation = 0.0
		p2.panning_strength = PANNING_STRENGTH
		player = p2
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Sfx"
	player.volume_db = volume_db + gain_of(stream)
	player.pitch_scale = maxf(pitch + randf_range(-pitch_jitter, pitch_jitter), 0.05)
	# 컷인·클래시처럼 트리가 멈춘 동안에도 끊기지 않게
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	root.add_child(player)
	if spot != null:
		(player as AudioStreamPlayer2D).global_position = spot.global_position
	player.play()
	return player

## 소리가 난 자리 — 부른 노드가 Node2D면 그것, 아니면(스킬은 Node라 좌표가 없다) 위로 올라가며 처음 만나는 Node2D
static func _spot_of(from: Node) -> Node2D:
	var node: Node = from
	while node != null:
		if node is Node2D:
			return node
		node = node.get_parent()
	return null
