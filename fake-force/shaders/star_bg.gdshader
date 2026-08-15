shader_type canvas_item;
// 动态星空背景：星云 + 星星（全程序化，无外部纹理）
// uniform:
//   g_strength  : 0~3 幻觉强度，增大时星云与星星整体变暗（系统压制感）
//   insight_mode: 0/1 洞察模式，=1 时星空定格（星星闪烁与星云旋转全部冻结）

uniform float g_strength : hint_range(0.0, 3.0) = 0.0;
uniform int insight_mode = 0;

// 像素坐标伪随机
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// 洞察模式：时间冻结（星空定格）
	float t = mix(TIME, 0.0, float(insight_mode));

	vec2 uv = UV - 0.5;

	// —— 星云：缓慢旋转 + 角度/半径多层正弦噪声 ——
	float rot = t * 0.03;
	vec2 ruv = vec2(uv.x * cos(rot) - uv.y * sin(rot), uv.x * sin(rot) + uv.y * cos(rot));
	float a = atan(ruv.y, ruv.x);
	float r = length(ruv);
	float n = 0.0;
	n += 0.55 * sin(a * 3.0 + r * 2.2 - t * 0.25);
	n += 0.30 * sin(a * 5.0 + r * 4.5 + t * 0.12);
	n += 0.15 * sin(a * 8.0 - r * 1.6 + t * 0.06);

	vec3 col = vec3(0.06, 0.10, 0.22);
	col += vec3(0.10, 0.13, 0.22) * (n * 0.5 + 0.5);
	col += vec3(0.08, 0.03, 0.16) * (sin(n * 6.283 + 1.0) * 0.5 + 0.5); // 紫调

	// —— 星星：像素坐标伪随机稀疏点阵 + 独立闪烁 ——
	vec2 grid = floor(UV * 100.0);
	vec2 cell = fract(UV * 100.0) - 0.5;
	float h = hash21(grid);
	float star = step(0.965, h);                    // 稀疏点阵
	float dcell = length(cell);
	float size = mix(0.006, 0.030, h);
	float glow = smoothstep(size, 0.0, dcell);
	float tw = 0.5 + 0.5 * sin(t * (1.5 + h * 7.0) + h * 47.0); // 每颗星独立闪烁
	col += vec3(0.9, 0.95, 1.0) * star * glow * tw * 1.2;

	// —— G 值增大 → 整体变暗（系统压制） ——
	float darken = 1.0 - clamp(g_strength, 0.0, 3.0) * 0.15;
	col *= darken;

	COLOR = vec4(col, 1.0);
}
