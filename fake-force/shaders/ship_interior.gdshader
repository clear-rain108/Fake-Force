shader_type canvas_item;
// 飞船内部背景（金属科幻风）：拉丝金属 + 分块面板 + 铆钉 + 发光灯条 + 指示灯 + 扫描光 + 弯曲管线
// uniform: g_strength 幻觉强度（增大时整体变暗，与太空背景的系统压制感一致）

uniform float g_strength : hint_range(0.0, 3.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 值噪声（金属质感）
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 分形噪声（面板分块）
float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.27 * noise(p * 2.02) + 0.18 * noise(p * 4.05);
}

void fragment() {
	vec2 uv = UV;
	// 金属底色（暗蓝灰）
	vec3 col = vec3(0.09, 0.11, 0.14);

	// —— 拉丝金属：斜向细密条纹 + 大块明暗 ——
	float brush = 0.5 + 0.5 * sin((uv.x * 0.35 + uv.y) * 280.0);
	col += vec3(0.02, 0.02, 0.03) * brush;
	float n2 = noise(uv * 5.0 + 13.7);
	col += vec3(0.035, 0.04, 0.045) * (n2 - 0.5) * 2.0;

	// —— 分块金属面板（2x2）：明暗差异 + 接缝亮线 + 四角铆钉 ——
	vec2 panel_uv = uv * 2.0;
	vec2 cell = floor(panel_uv);
	vec2 fcell = fract(panel_uv);
	float h = hash21(cell);
	col *= 0.93 + 0.10 * h;
	// 接缝（细亮线）
	vec2 seam = smoothstep(0.0, 0.03, fcell) * smoothstep(1.0, 0.97, fcell);
	col += vec3(0.06, 0.07, 0.08) * (1.0 - min(seam.x, seam.y));
	// 四角铆钉
	float riv = 0.0;
	riv += smoothstep(0.04, 0.0, distance(fcell, vec2(0.08, 0.08)));
	riv += smoothstep(0.04, 0.0, distance(fcell, vec2(0.92, 0.08)));
	riv += smoothstep(0.04, 0.0, distance(fcell, vec2(0.08, 0.92)));
	riv += smoothstep(0.04, 0.0, distance(fcell, vec2(0.92, 0.92)));
	col += vec3(0.16, 0.17, 0.19) * riv;

	// —— 斜切金属板高光 ——
	float plate = step(0.993, noise(uv * 2.0 + 7.0));
	col += vec3(0.10, 0.11, 0.12) * plate;

	// —— 弯曲管线 ——
	float pipe = step(0.995, fbm(uv * 3.0 + 5.0));
	col = mix(col, vec3(0.30, 0.27, 0.22), pipe);

	// —— 发光灯条（横向灯带 + 辉光） ——
	float line = abs(fract(uv.y * 4.0) - 0.5);
	float strip = smoothstep(0.47, 0.44, line);
	float glow = exp(-line * 10.0) * 0.25;
	col += vec3(0.2, 0.75, 1.0) * (strip * 0.35 + glow);

	// —— 面板指示灯（随机小亮点，独立闪烁） ——
	vec2 lcell = floor(uv * vec2(22.0, 18.0));
	float lh = hash21(lcell);
	float lamp = step(0.986, lh);
	float blink = 0.5 + 0.5 * sin(TIME * (1.0 + lh * 3.0) + lh * 20.0);
	col += vec3(0.3, 0.7, 1.0) * lamp * (0.25 + 0.75 * blink);

	// —— 扫描光带（缓慢扫过） ——
	float scan = fract(TIME * 0.045);
	float band = exp(-pow((uv.y - scan) * 10.0, 2.0));
	col += vec3(0.05, 0.09, 0.12) * band;

	// —— G 值变暗（系统压制） ——
	col *= 1.0 - clamp(g_strength, 0.0, 3.0) * 0.12;

	COLOR = vec4(col, 1.0);
}

