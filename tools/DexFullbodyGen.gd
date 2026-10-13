extends SceneTree

## **도감 전신 그림을 뽑는 도구**(2026-10-11 사용자: "층간소음 모자 전신 사진 넣어줘,
## 아이를 발 정도에 위치시켜서 다 나오도록"). 리그 씬을 투명 배경에 그려 PNG로 저장한다.
##
## 그림이 캔버스에 꽉 차도록 **인물의 실제 테두리를 재서** 배율과 자리를 스스로 정한다 —
## 손으로 맞추면 캐릭터마다 다시 재야 한다.
##
## 층간소음은 엄마가 아이를 들쳐업은 한 쌍이라, 아이(`Carry`)를 리그에서 **떼어내** 엄마 옆에
## 따로 세운다. 안 떼면 BodyRig이 제 자리로 되돌려 놓는다(업은 자리를 스스로 관리한다).
## 쓰는 법: Godot --path . -s tools/DexFullbodyGen.gd

const OUT_SIZE := Vector2i(471, 491)
const OUT_PATH := "res://_dex_fullbody_out.png"
## 캐릭터 이름 -> 리그 씬. 쓸 때 `-- "지하철 아저씨"`처럼 이름을 넘긴다
const RIGS := {
	"층간소음 모자": "res://characters/floornoise/FloorNoiseRig.tscn",
	"지하철 아저씨": "res://characters/subwayvillain/SubwayVillainRig.tscn",
	"고양이 아주머니": "res://characters/catmom/CatMomRig.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/JujeongbaengiRig.tscn",
	"악플러": "res://characters/akpeulleo/AkpeulleoRig.tscn",
	"일진": "res://characters/iljin/IljinRig.tscn",
	"금쪽이": "res://characters/chokbeopsonyeon/ChokbeopsonyeonRig.tscn",
	"경찰": "res://characters/police/PoliceRig.tscn",
}
## 인물이 차지할 비율 — 1이면 테두리가 캔버스에 딱 붙는다.
## 먼저 찍어 둔 넉 장이 0.90~0.94라 맞춰 둔다. 층간소음만 엄마와 아이가 가로로 늘어서서 따로 본다
const DEFAULT_FILL := 0.92
const FILLS := {"층간소음 모자": 0.82}
## 아이를 엄마 몸통에 얼마나 겹칠지(리그 기준). 아이는 **엄마 뒤쪽 발치**에 선다 —
## 옆으로 나란히 세우면 그림이 가로로 넓어져 도감 칸(기울어진 평행사변형)에서 잘린다(실측)
const KID_OVERLAP := 4.0

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = OUT_SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# 엄마와 아이를 함께 담아 통째로 키우고 옮길 바구니
	var stage := Node2D.new()
	vp.add_child(stage)
	var who: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "층간소음 모자"
	if not RIGS.has(who):
		print("모르는 캐릭터: ", who)
		quit()
		return
	var fill: float = FILLS.get(who, DEFAULT_FILL)
	var rig: Node2D = load(RIGS[who]).instantiate()
	stage.add_child(rig)

	# 리그가 제 자리를 잡을 틈을 준다(포즈·들쳐업기 보정이 _process에서 돈다)
	for i in 12:
		await process_frame
	_freeze(rig)

	var kid: Node2D = rig.get_node_or_null("Carry")
	if kid != null:
		rig.remove_child(kid)
		stage.add_child(kid)
		kid.z_index = 0
		await process_frame
		var mom_box: Rect2 = _bounds(stage, rig)
		var kid_box: Rect2 = _bounds(stage, kid)
		var body: Node2D = rig.get_node_or_null("Body")
		var body_box: Rect2 = _bounds(stage, body) if body != null else mom_box
		# 가로: 엄마 몸통 왼쪽에 살짝 겹쳐 세운다 / 세로: 발바닥을 엄마와 맞춘다
		kid.position += Vector2(
			body_box.position.x + KID_OVERLAP - kid_box.end.x,
			mom_box.end.y - kid_box.end.y)

	await process_frame
	var box: Rect2 = _bounds(stage, stage)
	var zoom: float = minf(OUT_SIZE.x * fill / box.size.x, OUT_SIZE.y * fill / box.size.y)
	stage.scale = Vector2(zoom, zoom)
	stage.position = Vector2(OUT_SIZE) * 0.5 - box.get_center() * zoom

	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = vp.get_texture().get_image()
	image.save_png(OUT_PATH)
	print("saved %s  (%s) box=%s zoom=%.2f" % [OUT_PATH, who, box, zoom])
	quit()

## `node` 안의 보이는 조각을 전부 감싸는 사각형을 `space` 좌표로 돌려준다
func _bounds(space: Node2D, node: Node2D) -> Rect2:
	var box := Rect2()
	var first := true
	var to_space: Transform2D = space.get_global_transform().affine_inverse()
	for c in _all_sprites(node):
		if not c.visible or c.modulate.a <= 0.01:
			continue
		var r: Rect2 = (to_space * c.get_global_transform()) * c.get_rect()
		if first:
			box = r
			first = false
		else:
			box = box.merge(r)
	return box

func _all_sprites(node: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for c in node.get_children():
		if c is Sprite2D:
			out.append(c)
		out.append_array(_all_sprites(c))
	return out

## 리그가 스스로 움직이는 것을 멈춘다
func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for c in node.get_children():
		_freeze(c)
