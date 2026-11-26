class_name AudioGen
extends RefCounted
## Sonidos generados por código (sin archivos): bocina y choque.

const RATE := 22050

static func horn() -> AudioStreamWAV:
	var n: int = int(RATE * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / RATE
		var s: float = (signf(sin(TAU * 440.0 * t)) + signf(sin(TAU * 554.0 * t))) * 0.5
		s += sin(TAU * 880.0 * t) * 0.2
		data.encode_s16(i * 2, int(clampf(s * 0.35, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

static func crash() -> AudioStreamWAV:
	var n: int = int(RATE * 0.6)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t: float = float(i) / RATE
		var env: float = exp(-t * 7.0)
		var s: float = (rng.randf_range(-1.0, 1.0) * 0.8 + sin(TAU * 70.0 * t) * 0.9) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
