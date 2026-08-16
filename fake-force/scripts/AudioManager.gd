extends Node
## AudioManager（Autoload）：程序化游戏内音效系统
## - 常驻 Ambient Drone：双 AudioStreamGenerator 流（低频正弦叠 73Hz 谐波 + 高频三角波），
##   与 IllusionManager 的 G 值 / 洞察状态实时联动；洞察时 LowPass 800→3000Hz + 高频饱和。
## - 移动风声：粉红噪声 + 带通近似，带通中心频率 ∝ 虚假力长度，音量 ∝ 速度²。
## - 一次性 SFX：洞察扫频 / 尘埃捕获 / 记事本拍频 / 黑洞跃迁序列（AudioStreamGenerator 动态合成）。
## - 音量控制：音乐（Music 总线）/ 音效（SFX+Ambient+Voice），持久化到 user://settings.cfg。

const MIX_RATE : int = 44100
const BUFFER_LENGTH : float = 0.25
const BUS_MUSIC := "Music"
const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"
const BUS_VOICE := "Voice"

# —— 音量（0~1，持久化） ——
var music_volume : float = 1.0
var sfx_volume : float = 1.0

# —— 常驻流 ——
var _drone_low : AudioStreamPlayer
var _drone_high : AudioStreamPlayer
var _wind : AudioStreamPlayer
var _dl_pb : AudioStreamGeneratorPlayback
var _dh_pb : AudioStreamGeneratorPlayback
var _wind_pb : AudioStreamGeneratorPlayback
var _dl_phase : float = 0.0
var _dh_phase : float = 0.0
var _lfo_phase : float = 0.0
var _low_freq : float = 55.0
var _wind_lp1 : float = 0.0
var _wind_lp2 : float = 0.0

# —— 一次性 SFX 队列 ——
class SfxJob:
	var player : AudioStreamPlayer
	var playback : AudioStreamGeneratorPlayback
	var samples : PackedVector2Array
	var idx : int = 0

var _sfx_jobs : Array = []

# —— 结局序列 ——
var _ending_active : bool = false
var _ending_t : float = 0.0
var _grav_sent : bool = false
var _pulse_sent : bool = false

const _CFG_PATH := "user://settings.cfg"


func _ready() -> void:
	_load_volumes()
	_apply_all_volumes()
	# 常驻 Drone + 风声
	_drone_low = _make_gen_player(BUS_AMBIENT)
	_drone_high = _make_gen_player(BUS_AMBIENT)
	_wind = _make_gen_player(BUS_AMBIENT)
	_drone_low.play()
	_drone_high.play()
	_wind.play()
	_dl_pb = _drone_low.get_stream_playback() as AudioStreamGeneratorPlayback
	_dh_pb = _drone_high.get_stream_playback() as AudioStreamGeneratorPlayback
	_wind_pb = _wind.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_update_lowpass(delta)
	_update_drone(delta)
	_update_wind()
	_process_sfx(delta)


# ==================== 常驻环境音（Drone） ====================

func _make_gen_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = MIX_RATE
	g.buffer_length = BUFFER_LENGTH
	p.stream = g
	p.bus = bus
	add_child(p)
	return p


func _update_lowpass(delta: float) -> void:
	var amb_idx := AudioServer.get_bus_index(BUS_AMBIENT)
	if amb_idx < 0 or AudioServer.get_bus_effect_count(amb_idx) <= 0:
		return
	var lp := AudioServer.get_bus_effect(amb_idx, 0)
	if lp is AudioEffectLowPassFilter:
		var target : float = 3000.0 if IllusionManager.is_insight_mode else 800.0
		lp.cutoff_hz = lerpf(lp.cutoff_hz, target, minf(delta * 8.0, 1.0))


func _update_drone(delta: float) -> void:
	if _dl_pb == null or _dh_pb == null:
		return
	var g := IllusionManager.current_g_value
	var insight := IllusionManager.is_insight_mode
	# 低频基频 55→75Hz 随 G 线性上移（区域过渡平滑 0.5s）
	_low_freq = lerpf(_low_freq, lerpf(55.0, 75.0, clampf(g / 3.0, 0.0, 1.0)), minf(delta / 0.5, 1.0))
	var low_amp : float = lerpf(0.30, 0.12, clampf(g / 3.0, 0.0, 1.0))
	_lfo_phase += 0.1 * TAU * delta
	var lfo := sin(_lfo_phase) * 0.15
	if _ending_active:
		low_amp *= maxf(1.0 - _ending_t, 0.0)
	# 低频层：55Hz 正弦 + 73Hz 二次谐波，LFO 相位漂移
	var n1 := _dl_pb.get_frames_available()
	for i in n1:
		_dl_phase += TAU * _low_freq * (1.0 + lfo) / float(MIX_RATE)
		var s := sin(_dl_phase) + 0.5 * sin(_dl_phase * (73.0 / 55.0))
		_dl_pb.push_frame(Vector2(s, s) * low_amp)
	# 高频层：220Hz 三角波，随机振幅微动；洞察时 5% 饱和失真
	var n2 := _dh_pb.get_frames_available()
	for i in n2:
		_dh_phase += TAU * 220.0 / float(MIX_RATE)
		var s : float = _triangle(_dh_phase)
		s *= 0.9 + randf() * 0.2
		if insight:
			s = clampf(s * 1.5, -0.12, 0.12)
		var amp : float = 0.10
		if _ending_active:
			amp *= maxf(1.0 - _ending_t, 0.0)
		_dh_pb.push_frame(Vector2(s, s) * amp)


func _update_wind() -> void:
	if _wind_pb == null:
		return
	var player := get_tree().get_first_node_in_group("Player")
	var vel : float = 0.0
	if is_instance_valid(player):
		vel = player.velocity.length()
	var fake_len : float = IllusionManager.get_current_fake_vector().length()
	# 带通中心频率 ∝ 虚假力长度（200~1500Hz）
	var band_freq : float = 200.0 + clampf(fake_len / 120.0, 0.0, 1.0) * 1300.0
	var alpha : float = clampf(band_freq / (float(MIX_RATE) * 0.5), 0.0, 1.0)
	var n := _wind_pb.get_frames_available()
	for i in n:
		var w := randf_range(-1.0, 1.0)
		_wind_lp1 += alpha * (w - _wind_lp1)
		_wind_lp2 += alpha * (_wind_lp1 - _wind_lp2)
		var s := (_wind_lp1 - _wind_lp2) * 4.0
		var vol : float = clampf(vel * vel / 10000.0, 0.0, 0.22)
		if vel < 10.0 and fake_len > 0.5:
			vol = maxf(vol, 0.04)  # 静止但被牵引：极小低频嗡鸣
		if _ending_active:
			vol *= maxf(1.0 - _ending_t, 0.0)
		_wind_pb.push_frame(Vector2(s, s) * vol)

# ==================== 一次性 SFX ====================

func _enqueue_sfx(samples: PackedVector2Array, bus: String = BUS_SFX) -> void:
	if samples.is_empty():
		return
	var player := AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = MIX_RATE
	g.buffer_length = 0.2
	player.stream = g
	player.bus = bus
	add_child(player)
	player.play()
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		player.queue_free()
		return
	var job := SfxJob.new()
	job.player = player
	job.playback = pb
	job.samples = samples
	_sfx_jobs.append(job)


func _process_sfx(delta: float) -> void:
	if _ending_active:
		_ending_t += delta
		if _ending_t >= 1.5 and not _grav_sent:
			_grav_sent = true
			_enqueue_sfx(_grav_wave_samples(), BUS_SFX)
		if _ending_t >= 3.0 and not _pulse_sent:
			_pulse_sent = true
			_enqueue_sfx(_pulse_samples(), BUS_SFX)
	var keep : Array = []
	for job in _sfx_jobs:
		if job.playback == null:
			continue
		var avail : int = job.playback.get_frames_available()
		var cnt : int = mini(avail, job.samples.size() - job.idx)
		for i in cnt:
			job.playback.push_frame(job.samples[job.idx])
			job.idx += 1
		if job.idx >= job.samples.size():
			job.player.stop()
			job.player.queue_free()
			continue
		keep.append(job)
	_sfx_jobs = keep


## 洞察切换扫频音（Shift）
func transition_insight_mode(entering: bool) -> void:
	if entering:
		# 300→1200Hz 上扫 0.25s，attack 0.02 / release 0.2（快起慢衰）
		_enqueue_sfx(_sweep_samples(300.0, 1200.0, 0.25, 0.02, 0.2, 0.35))
	else:
		# 800→150Hz 下扫 0.3s，attack 0.1 / release 0.05（慢起快衰）
		_enqueue_sfx(_sweep_samples(800.0, 150.0, 0.3, 0.1, 0.05, 0.3))


## 收集马赫尘埃
func play_dust_collect() -> void:
	var n := int(0.15 * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var freq := lerpf(1400.0, 300.0, k * k)
		phase += TAU * freq / float(MIX_RATE)
		var env := (1.0 - k) * (1.0 - k)
		out[i] = Vector2(sin(phase), sin(phase)) * env * 0.4
	_enqueue_sfx(out)
	# 混响尾音 0.1s
	var t2 := int(0.1 * MIX_RATE)
	var tail := PackedVector2Array()
	tail.resize(t2)
	var p2 := 0.0
	for i in t2:
		var k := float(i) / float(t2)
		p2 += TAU * 300.0 / float(MIX_RATE)
		tail[i] = Vector2(sin(p2), sin(p2)) * (1.0 - k) * 0.15
	_enqueue_sfx(tail)


## 记事本浮现文字（拍频）
func play_notebook_reveal() -> void:
	var n := int(0.4 * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var k := float(i) / float(n)
		p1 += TAU * 440.0 / float(MIX_RATE)
		p2 += TAU * 445.0 / float(MIX_RATE)
		var s : float = (sin(p1) + sin(p2)) * 0.5
		out[i] = Vector2(s, s) * (1.0 - k) * 0.3
	_enqueue_sfx(out)


## 进入新幻觉区域：触发环境音低频层向新区域预设平滑过渡
func transition_zone(_g_value: float) -> void:
	# Drone 基频目标随 IllusionManager.current_g_value 每帧更新（55→75Hz），
	# 此处保持当前相位连续性，由 _update_drone 的 0.5s lerp 平滑趋近，避免阶跃爆音。
	pass


## 结局：黑洞跃迁序列（常驻环境音淡出由 _process 控制）
func play_blackhole_sequence() -> void:
	if _ending_active:
		return
	_ending_active = true
	_ending_t = 0.0
	_grav_sent = false
	_pulse_sent = false



# ==================== 波形生成 ====================

func _triangle(ph: float) -> float:
	return 2.0 * absf(2.0 * (ph / TAU - floor(ph / TAU + 0.5))) - 1.0


func _sweep_samples(f0: float, f1: float, dur: float, attack: float, release: float, amp: float) -> PackedVector2Array:
	var n := int(dur * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := lerpf(f0, f1, t / dur)
		phase += TAU * freq / float(MIX_RATE)
		var s : float = 2.0 * (phase / TAU - floor(phase / TAU + 0.5))  # 锯齿波
		var env : float = 1.0
		if t < attack:
			env = t / attack
		elif t > dur - release:
			env = maxf((dur - t) / release, 0.0)
		out[i] = Vector2(s, s) * env * amp
	return out


func _grav_wave_samples() -> PackedVector2Array:
	var dur := 1.5
	var n := int(dur * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var k := t / dur
		var lfo := sin(TAU * 0.05 * t) * 2.0
		phase += TAU * (30.0 + lfo) / float(MIX_RATE)
		out[i] = Vector2(sin(phase), sin(phase)) * (k * 0.4)
	return out


func _pulse_samples() -> PackedVector2Array:
	var n := int(0.1 * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		phase += TAU * 2000.0 / float(MIX_RATE)
		var env := sin(PI * k)  # 平滑包络，防爆音
		out[i] = Vector2(sin(phase), sin(phase)) * env * 0.3
	return out

# ==================== 音量控制（持久化） ====================

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_save_volumes()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	for b in [BUS_SFX, BUS_AMBIENT, BUS_VOICE]:
		_apply_bus_volume(b, sfx_volume)
	_save_volumes()


func _apply_all_volumes() -> void:
	_apply_bus_volume(BUS_MUSIC, music_volume)
	for b in [BUS_SFX, BUS_AMBIENT, BUS_VOICE]:
		_apply_bus_volume(b, sfx_volume)


func _apply_bus_volume(bus: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(vol, 0.0001, 1.0)))
		AudioServer.set_bus_mute(idx, vol <= 0.0001)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_CFG_PATH) == OK:
		music_volume = clampf(cfg.get_value("audio", "music", 1.0), 0.0, 1.0)
		sfx_volume = clampf(cfg.get_value("audio", "sfx", 1.0), 0.0, 1.0)


func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_CFG_PATH)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(_CFG_PATH)

