@tool
extends Node2D

## 팝아트(벤데이 점) 배경 — 만화 칸 바탕에 **동그라미 점 무늬가 처음부터 끝까지 깔려 있다**(2026-10-10 사용자: 고양이 아주머니 검은 고양이 궁 컷인).
## 칸(`Polygon2D`, clip_children)의 자식으로 두면 칸 모양대로 잘린다. 점은 엇갈린 격자(한 줄씩 반 칸 밀림)로 찍는다.
## 그림은 한 번만 그리고, 값이 바뀔 때만 다시 그린다(점이 수천 개라 매 프레임 그리면 아깝다)

## 점을 찍을 범위(이 노드 기준, px) — 칸보다 넉넉하게 잡으면 된다
@export var area: Rect2 = Rect2(-700, -420, 1400, 840):
	set(v):
		area = v
		queue_redraw()
## 점 사이 간격(px)과 점 반지름(px)
@export var spacing: float = 22.0:
	set(v):
		spacing = maxf(v, 4.0)
		queue_redraw()
@export var radius: float = 6.0:
	set(v):
		radius = v
		queue_redraw()
## 점 색 — 칸마다 다르게 주면 팝아트 느낌이 난다
@export var dot_color: Color = Color(1.0, 0.45, 0.6, 0.45):
	set(v):
		dot_color = v
		queue_redraw()
## 한쪽 모서리로 갈수록 점이 작아지는 정도(0 = 모두 같은 크기). 1이면 반대편 끝에서 점이 사라진다
@export_range(0.0, 1.0, 0.05) var fade_across: float = 0.45:
	set(v):
		fade_across = v
		queue_redraw()
## 점이 작아지는 방향(도) — 0이면 오른쪽으로 갈수록 작아진다
@export var fade_deg: float = 30.0:
	set(v):
		fade_deg = v
		queue_redraw()

func _draw() -> void:
	var dir := Vector2.from_angle(deg_to_rad(fade_deg))
	var half: float = absf(dir.x) * area.size.x * 0.5 + absf(dir.y) * area.size.y * 0.5
	var center: Vector2 = area.get_center()
	var row: int = 0
	var y: float = area.position.y
	while y <= area.end.y:
		var x: float = area.position.x + (spacing * 0.5 if row % 2 == 1 else 0.0)
		while x <= area.end.x:
			var p := Vector2(x, y)
			# 기준 방향으로 얼마나 갔는지(-1~1) → 0~1로 바꿔 점 크기를 줄인다
			var k: float = clampf(((p - center).dot(dir) / maxf(half, 1.0)) * 0.5 + 0.5, 0.0, 1.0)
			var r: float = radius * (1.0 - fade_across * k)
			if r > 0.4:
				draw_circle(p, r, dot_color)
			x += spacing
		y += spacing * 0.866
		row += 1
