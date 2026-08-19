shader_type canvas_item;
// 飞船内部背景 —— “扫描仪器”风（重写 v2）
// ---------------------------------------------------------------------------
// 与主菜单星云（star_bg.gdshader）风格统一：深海军蓝底色 + 细线/低透明仪器元素，
// 完全去除金属块/面板等大色块（解决色块污染）。
//
// 仪器元素（全部程序化，无外部纹理）：
//   示波器细网格 / 声纳同心环 / 旋转扫描波束 / 声纳目标光点 / 中心十字准星 /
//   虚假力方向指示针 / 纵向 CRT 扫描线 / 边沿刻度 / 取景框角标
//
// 玩家“矫正参考系”时的合理变化：
//   1) 洞察模式（insight_mode=1，按住 Shift 测量/校正参考系）
//      —— 所有动画定格（与太空星云定格一致）；红色虚线校准环 + 旋转对准刻度浮现，
//         虚假力指示针转红加亮（与红虚线虚假力箭头同色）；
//   2) 参考系校准中（sync_state=1，旋转参考系切换 ROT_SWITCHING）
//      —— 校准环/对准刻度快速旋转（对准同步），扫描波束提速；
//   3) 参考系已同步（sync_state=2，ROT_SYNCED）
//      —— 金色实线锁定环 + 锁定刻度（与金色目标向心力箭头呼应），波束进入稳态；
//   4) 旋转参考系（omega>0）：声纳波束/目标光点公转转速随 omega 加快。
//
// uniform:
//   g_strength  : 0~3 幻觉强度，增大时整体变暗（系统压制，与太空背景一致）
//   insight_mode: 0/1 洞察模式
//   sync_state  : 0=横向参考系  1=参考系校准中  2=已同步
//   omega       : 旋转参考系角速度（rad/s）
//   fake_dir    : 当前虚假力方向（原始矢量；长度为 0 表示无虚假力）

uniform float g_strength : hint_range(0.0, 3.0) = 0.0;
uniform int insight_mode = 0;
uniform int sync_state = 0;
uniform float omega : hint_range(0.0, 3.0) = 0.0;
uniform vec2 fake_dir = vec2(0.0, 0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 点到线段距离
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - (a + ab * h));
}

void fragment() {
	vec2 p = UV - 0.5;
	// 洞察模式：时间定格（仪器冻结，与星空定格一致）
	float t = mix(TIME, 0.0, float(insight_mode));

	// —— 深空底色（与主菜单星云同族） ——
	vec3 col = vec3(0.05, 0.08, 0.17);
	col += vec3(0.016, 0.032, 0.052) * exp(-length(p) * 3.2);   // 屏幕中心微弱聚焦

	vec3 cyan   = vec3(0.30, 0.62, 0.88);   // 仪器主色（青蓝）
	vec3 cyan_d = vec3(0.20, 0.40, 0.60);   // 暗青（低透明元素）
	vec3 gold   = vec3(1.0, 0.84, 0.0);     // 已同步锁定（与金色目标向心力箭头同色）
	vec3 red    = vec3(1.0, 0.30, 0.25);    // 洞察/虚假力（与红虚线虚假力箭头同色）

	float r = length(p);
	float ang = atan(p.y, p.x);

	// —— 示波器细网格（低透明，避免色块） ——
	vec2 gr = p * 10.0;
	vec2 minor = smoothstep(0.006, 0.0, abs(fract(gr) - 0.5));
	vec2 major = smoothstep(0.014, 0.0, abs(fract(gr * 0.5) - 0.5));
	float grid = max(max(minor.x, minor.y), max(major.x, major.y));
	col += cyan_d * grid * 0.08;

	// —— 声纳同心环 ——
	float ring = 0.0;
	ring = max(ring, smoothstep(0.0045, 0.0, abs(r - 0.14)));
	ring = max(ring, smoothstep(0.0045, 0.0, abs(r - 0.27)));
	ring = max(ring, smoothstep(0.0045, 0.0, abs(r - 0.40)));
	col += cyan_d * ring * 0.20;

	// —— 旋转扫描波束（声纳扫掠，转速随 omega；校准中提速） ——
	float cal_f  = step(0.5, float(sync_state)) * (1.0 - step(1.5, float(sync_state))); // sync_state==1
	float lock_f = step(1.5, float(sync_state));                                        // sync_state>=2
	float beam_rot = t * (0.28 + omega * 0.8 + cal_f * 1.6);
	float da = abs(mod(ang - beam_rot + PI, TAU) - PI);
	float beam = exp(-da * 7.0);
	float trail = exp(-da * 1.4) * 0.30;
	float beam_a = 0.30 - lock_f * 0.15;   // 已同步后波束微暗（锁定稳态）
	col += cyan * (beam * beam_a + trail * 0.06);

	// —— 声纳目标光点（环上伪随机光点，公转转速随 omega） ——
	float bp_rot = t * (0.35 + omega * 0.5);
	for (int i = 0; i < 3; i++) {
		float rr = 0.14 + 0.13 * float(i);
		float ba = hash21(vec2(float(i), 1.0));
		float bp = mod(ba * TAU + bp_rot * (0.6 + 0.4 * float(i)), TAU);
		vec2 bpos = vec2(cos(bp), sin(bp)) * rr;
		float blink = 0.5 + 0.5 * sin(t * 2.2 + ba * 37.0);
		col += cyan * smoothstep(0.012, 0.0, length(p - bpos)) * (0.08 + 0.22 * blink);
	}

	// —— 中心十字准星（细线） ——
	//vec2 ap = abs(p);
	//float cross = smoothstep(0.0035, 0.0, ap.x) * smoothstep(0.085, 0.075, ap.y)
		//+ smoothstep(0.0035, 0.0, ap.y) * smoothstep(0.085, 0.075, ap.x);
	//col += cyan * cross * 0.16;
	// 中心小点
	//col += cyan * smoothstep(0.006, 0.0, r) * 0.20;

	// —— 虚假力方向指示针 ——
	float has_f = step(0.001, length(fake_dir));
	vec2 fd = has_f > 0.5 ? normalize(fake_dir) : vec2(0.0, 1.0);
	vec2 nend = fd * 0.17;
	float needle = smoothstep(0.0035, 0.0, seg_dist(p, vec2(0.0), nend));
	float nhead = smoothstep(0.012, 0.0, length(p - nend));
	vec3 ncol = mix(cyan, red, float(insight_mode));
	float na = 0.30 + 0.30 * float(insight_mode);
	col += ncol * (needle + nhead * 0.8) * na * has_f;

	// —— 校准/锁定环（r=0.22） ——
	float cal_ring = smoothstep(0.004, 0.0, abs(r - 0.22));
	// 校准环：红色虚线，旋转对准（洞察/切换时浮现）
	float in_cal = max(cal_f, float(insight_mode));
	float dash = step(0.5, fract(ang / TAU * 10.0 - t * (1.2 + 2.0 * cal_f)));
	col += red * cal_ring * dash * 0.30 * in_cal;
	// 锁定环：金色实线
	col += gold * cal_ring * lock_f * 0.35;
	// 环外 4 个对准刻度（校准中旋转 / 锁定后固定）
	float tick = 0.0;
	for (int i = 0; i < 4; i++) {
		float ta = float(i) * TAU / 4.0 + t * 1.8 * cal_f;
		vec2 tp = vec2(cos(ta), sin(ta)) * 0.25;
		tick = max(tick, smoothstep(0.007, 0.0, length(p - tp)));
	}
	col += tick * (red * 0.30 * in_cal + gold * 0.40 * lock_f);

	// —— 纵向 CRT 扫描线（缓慢扫过） ——
	float scan_y = fract(t * 0.08);
	float scan = exp(-pow((p.y + 0.5 - scan_y) * 13.0, 2.0));
	col += cyan * scan * 0.045;

	// —— 边沿刻度（左右两侧细刻度，模拟仪器读数） ——
	float etick = 0.0;
	for (int i = 0; i < 9; i++) {
		float ty = -0.4 + 0.1 * float(i);
		etick = max(etick, smoothstep(0.008, 0.0, seg_dist(p, vec2(-0.475, ty), vec2(-0.475 + 0.025, ty))));
		etick = max(etick, smoothstep(0.008, 0.0, seg_dist(p, vec2(0.475 - 0.025, ty), vec2(0.475, ty))));
	}
	col += cyan_d * etick * 0.14;

	// —— 取景框角标（4 个 L 形，低透明） ——
	//float bracket = 0.0;
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(-0.455, -0.345), vec2(-0.455, -0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(-0.455, -0.455), vec2(-0.345, -0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(0.345, -0.455), vec2(0.455, -0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(0.455, -0.455), vec2(0.455, -0.345))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(0.455, 0.345), vec2(0.455, 0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(0.455, 0.455), vec2(0.345, 0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(-0.345, 0.455), vec2(-0.455, 0.455))));
	//bracket = max(bracket, smoothstep(0.005, 0.0, seg_dist(p, vec2(-0.455, 0.455), vec2(-0.455, 0.345))));
	//col += cyan_d * bracket * 0.26;

	// —— G 值增大 → 整体变暗（系统压制，与太空一致） ——
	float darken = 1.0 - clamp(g_strength, 0.0, 3.0) * 0.16;
	col *= darken;

	COLOR = vec4(col, 1.0);
}

