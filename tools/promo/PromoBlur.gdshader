shader_type canvas_item;

// 홍보 영상용 화면 전체 흐림 — 화면을 원 모양으로 여러 번 뽑아 평균(밉맵에 기대지 않음)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius_px = 0.0;

void fragment() {
	if (radius_px < 0.05) {
		COLOR = texture(screen_tex, SCREEN_UV);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * radius_px;
		vec4 sum = vec4(0.0);
		float total = 0.0;
		for (int r = 1; r <= 4; r++) {
			float rr = float(r) / 4.0;
			for (int a = 0; a < 12; a++) {
				float ang = float(a) * 0.5236 + float(r) * 0.37;
				sum += texture(screen_tex, SCREEN_UV + vec2(cos(ang), sin(ang)) * px * rr);
				total += 1.0;
			}
		}
		sum += texture(screen_tex, SCREEN_UV);
		COLOR = sum / (total + 1.0);
	}
}
