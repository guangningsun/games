extends Node
## SoundManager —— 音效 + BGM 管理（autoload 单例）
##
## M5 阶段：所有音效都是程序生成（sine 波 + 简单包络）
## - PC 平台：完全可用
## - 微信小游戏：可用（注意 BGM 在微信需 wx.getBackgroundAudioManager）
##
## 接口：
##   SoundManager.play_sfx("hit_brick" | "hit_wall" | "hit_paddle" | "lose" | "clear" | "click")
##   SoundManager.play_bgm()    # 启动循环 BGM
##   SoundManager.stop_bgm()
##   SoundManager.set_sfx_volume(0.0 ~ 1.0)
##   SoundManager.set_bgm_volume(0.0 ~ 1.0)
##
## M6 TODO：用真实音频文件替换程序生成（高保真音效）

const SAMPLE_RATE: int = 22050
const MASTER_VOLUME: float = 0.4

var _sfx_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer
var _sfx_streams: Dictionary = {}
var _sfx_volume: float = 1.0
var _bgm_volume: float = 0.6
var _enabled: bool = true


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_sfx_player.bus = "SFX"
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.bus = "Music"
	_bgm_player.autoplay = false

	# 程序生成所有 SFX（懒加载也可以，这里一次生成）
	_sfx_streams["hit_wall"] = _make_blip(600.0, 0.04, 0.5)
	_sfx_streams["hit_paddle"] = _make_blip(450.0, 0.06, 0.6)
	_sfx_streams["hit_brick"] = _make_sweep(800.0, 200.0, 0.08, 0.7)
	_sfx_streams["hit_brick_strong"] = _make_sweep(1000.0, 400.0, 0.10, 0.7)
	_sfx_streams["lose"] = _make_sweep(400.0, 80.0, 0.4, 0.7)
	_sfx_streams["clear"] = _make_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.12)
	_sfx_streams["click"] = _make_blip(700.0, 0.03, 0.5)


## 播放一次性音效
func play_sfx(name: String) -> void:
	if not _enabled:
		return
	if not _sfx_streams.has(name):
		push_warning("SoundManager: unknown sfx '%s'" % name)
		return
	_sfx_player.stream = _sfx_streams[name]
	_sfx_player.volume_db = linear_to_db(_sfx_volume * MASTER_VOLUME)
	_sfx_player.play()


## 启动循环 BGM
func play_bgm() -> void:
	if not _enabled:
		return
	_bgm_player.stream = _make_bgm()
	_bgm_player.volume_db = linear_to_db(_bgm_volume * MASTER_VOLUME)
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()


func set_sfx_volume(v: float) -> void:
	_sfx_volume = clampf(v, 0.0, 1.0)


func set_bgm_volume(v: float) -> void:
	_bgm_volume = clampf(v, 0.0, 1.0)
	if _bgm_player.playing:
		_bgm_player.volume_db = linear_to_db(_bgm_volume * MASTER_VOLUME)


func set_enabled(e: bool) -> void:
	_enabled = e
	if not e:
		stop_bgm()


# ============================================================
#                  程序生成音效 helpers
# ============================================================

## 单频 beep，duration 秒
func _make_blip(frequency: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 1.0 - float(i) / samples  # 线性衰减
		env = env * env  # 平方衰减让声音更自然
		var sample: float = sin(TAU * frequency * t) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)


## 扫频：从 start_freq 到 end_freq
func _make_sweep(start_freq: float, end_freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		var progress: float = float(i) / samples
		# 频率随时间线性变化（但用对数感觉更自然）
		var freq: float = lerp(start_freq, end_freq, progress)
		var env: float = (1.0 - progress) * (1.0 - progress)  # 平方衰减
		var sample: float = sin(TAU * freq * t) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)


## 琶音：依次播放 notes Hz，每个 note_duration 秒
func _make_arpeggio(notes: Array, note_duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var total_samples: int = int(SAMPLE_RATE * note_duration * notes.size())
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)
	for i in total_samples:
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = int(t / note_duration)
		if note_idx >= notes.size():
			note_idx = notes.size() - 1
		var freq: float = notes[note_idx]
		var local_t: float = fmod(t, note_duration)
		var env: float = 1.0 - (local_t / note_duration)
		env = env * env
		var sample: float = sin(TAU * freq * t) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)


## 简单循环 BGM：两段旋律 A-B-A-B，4 秒循环
func _make_bgm() -> AudioStreamWAV:
	# 简单旋律（C 大调）
	var melody_a: Array = [261.6, 329.6, 392.0, 329.6, 261.6, 329.6, 293.7, 261.6]  # C E G E C E D C
	var note_duration: float = 0.25
	var total_duration: float = melody_a.size() * note_duration * 2  # 重复一次
	var samples: int = int(SAMPLE_RATE * total_duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = int(t / note_duration) % melody_a.size()
		var freq: float = melody_a[note_idx]
		var local_t: float = fmod(t, note_duration)
		var env: float = 0.5 + 0.5 * cos(TAU * local_t / note_duration * 2)  # 让音符有起伏
		# 叠加八度让音色更厚
		var sample: float = (sin(TAU * freq * t) + 0.5 * sin(TAU * freq * 2 * t)) * 0.25 * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)


func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var int_sample: int = int(clampf(sample, -1.0, 1.0) * 32767)
	data[index * 2] = int_sample & 0xFF
	data[index * 2 + 1] = (int_sample >> 8) & 0xFF


func _wrap_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream