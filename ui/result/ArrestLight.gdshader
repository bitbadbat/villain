shader_type canvas_item;

// 연행 장면 인물 조명(2026-10-11) — 게임의 `characters/RimLight.gdshader`(위에서 오는 빛)에 **빛을 하나 더** 얹은 것.
//  1. 주 빛(맵마다: 낮 = 햇빛, 번화가 밤 = 뒤 가게·간판 불빛) — 그쪽 가장자리에 윤곽광
//  2. 경광등 빛(빨강/파랑, 번쩍일 때만) — 경찰차 쪽 가장자리에 윤곽광. 장면이 매 프레임 색·세기를 넣는다
//  3. 주 빛 반대쪽 가장자리 그늘 + 파츠 안 위아래 명암
// 장면 하나가 **재질 하나**를 경찰·두 사람·아이·구경꾼이 같이 쓴다(빛 방향은 화면 기준이라 다 같다).
// 밤에 어둡게 하는 건 여기서 안 한다 — 층(Procession 등)의 modulate가 곱하고, 윤곽광은 그 위에 **더해져** 어둠 속에서도 빛난다.
// 그리는 법은 RimLight와 같다(안쪽으로 그림, 두께 = 화면 px, 방향은 MODEL_MATRIX 역으로 파츠 로컬로)

group_uniforms key;
uniform vec2 light_dir = vec2(-0.5, -1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_px : hint_range(0.5, 8.0) = 2.2;
uniform float rim_focus : hint_range(0.0, 1.0) = 0.55;

group_uniforms siren;
uniform vec2 siren_dir = vec2(-1.0, -0.35);
uniform vec4 siren_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float siren_strength : hint_range(0.0, 2.0) = 0.0;
uniform float siren_px : hint_range(0.5, 10.0) = 3.0;

group_uniforms shade;
uniform vec4 shade_color : source_color = vec4(0.10, 0.08, 0.16, 1.0);
uniform float shade_strength : hint_range(0.0, 1.0) = 0.25;
uniform float shade_px : hint_range(0.5, 12.0) = 3.0;
uniform float gradient_strength : hint_range(0.0, 0.5) = 0.08;

varying vec2 v_key;
varying vec2 v_siren;

vec2 to_local(mat2 m, vec2 d, vec2 fallback) {
	vec2 l = inverse(m) * d;
	return length(l) > 0.0001 ? normalize(l) : fallback;
}

void vertex() {
	mat2 m = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
	v_key = to_local(m, light_dir, vec2(0.0, -1.0));
	v_siren = to_local(m, siren_dir, vec2(-1.0, 0.0));
}

// 네 이웃 알파에서 가장자리 정도(0~1)와 바깥 법선 (RimLight와 같은 이유로 샘플링은 fragment에서)
void edge_from(float ax0, float ax1, float ay0, float ay1, out float edge, out vec2 normal) {
	edge = clamp(1.0 - min(min(ax0, ax1), min(ay0, ay1)), 0.0, 1.0);
	vec2 grad = vec2(ax1 - ax0, ay1 - ay0);
	normal = length(grad) > 0.001 ? -normalize(grad) : vec2(0.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a > 0.05) {
		vec2 fw = fwidth(UV);
		if (gradient_strength > 0.0) {
			float h = dot(UV - 0.5, v_key);
			COLOR.rgb *= 1.0 + gradient_strength * clamp(h * 2.0, -1.0, 1.0);
		}
		if (shade_strength > 0.0) {
			vec2 d = fw * shade_px;
			float edge; vec2 n;
			edge_from(texture(TEXTURE, UV - vec2(d.x, 0.0)).a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(0.0, d.y)).a, texture(TEXTURE, UV + vec2(0.0, d.y)).a, edge, n);
			float away = smoothstep(0.1, 0.8, dot(n, -v_key));
			COLOR.rgb = mix(COLOR.rgb, shade_color.rgb * COLOR.a, edge * away * shade_strength);
		}
		if (rim_strength > 0.0) {
			vec2 d = fw * rim_px;
			float edge; vec2 n;
			edge_from(texture(TEXTURE, UV - vec2(d.x, 0.0)).a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(0.0, d.y)).a, texture(TEXTURE, UV + vec2(0.0, d.y)).a, edge, n);
			float lit = smoothstep(rim_focus - 0.35, rim_focus + 0.35, dot(n, v_key));
			COLOR.rgb += rim_color.rgb * edge * lit * rim_strength * COLOR.a;
		}
		if (siren_strength > 0.0) {
			vec2 d = fw * siren_px;
			float edge; vec2 n;
			edge_from(texture(TEXTURE, UV - vec2(d.x, 0.0)).a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(0.0, d.y)).a, texture(TEXTURE, UV + vec2(0.0, d.y)).a, edge, n);
			float lit = smoothstep(-0.1, 0.6, dot(n, v_siren));
			// 가장자리 윤곽광 + 그쪽 면 전체에 옅게 번지는 빛(경광등은 가까워서 몸통까지 물든다)
			float wash = 0.18 * smoothstep(-0.2, 0.7, dot(UV - 0.5, v_siren) * 2.0);
			COLOR.rgb += siren_color.rgb * (edge * lit + wash) * siren_strength * COLOR.a;
		}
	}
}
