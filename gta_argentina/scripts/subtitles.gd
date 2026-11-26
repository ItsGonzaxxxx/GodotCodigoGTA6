class_name Subtitles
extends CanvasLayer
## Subtítulos estilo GTA (abajo, con nombre del que habla), notificaciones laterales
## ("+$300", "Te vieron…") y carteles grandes centrales ("DETENIDO").

var current_text: String = ""
var _queue: Array = []
var _cur_t: float = 0.0
var _cur_dur: float = 0.0
var _active: bool = false
var _panel: PanelContainer
var _label: RichTextLabel
var _toast_box: VBoxContainer
var _toasts: Array = []
var _banner: Label
var _banner_t: float = 0.0
var _banner_dur: float = 2.4

func _ready() -> void:
	layer = 20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("normal_font_size", 24)
	_label.add_theme_font_size_override("bold_font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_label)
	_toast_box = VBoxContainer.new()
	add_child(_toast_box)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 72)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	add_child(_banner)

static func speaker_color(name: String) -> Color:
	match name:
		"Policía": return Color(0.5, 0.7, 1.0)
		"Desconocido", "Chorro": return Color(1.0, 0.55, 0.45)
		"Vos": return Color(1.0, 0.9, 0.4)
		"Narrador": return Color(0.85, 0.85, 0.85)
		_: return Color(0.6, 0.92, 0.7)

func say(speaker: String, text: String, dur: float = -1.0) -> void:
	if dur < 0.0:
		dur = clampf(1.8 + text.length() * 0.055, 2.5, 8.0)
	_queue.append({"s": speaker, "t": text, "d": dur})
	while _queue.size() > 3:
		_queue.pop_front()

func clear() -> void:
	_queue.clear()
	_active = false
	current_text = ""
	_panel.visible = false

func notify(text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_toast_box.add_child(l)
	_toasts.append({"l": l, "t": 4.5})
	while _toasts.size() > 5:
		var old: Dictionary = _toasts.pop_front()
		old["l"].queue_free()

func banner(text: String, color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner_t = _banner_dur

func _process(delta: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = vp.x * 0.62
	_panel.custom_minimum_size.x = w
	_panel.position = Vector2((vp.x - w) / 2.0, vp.y - 130.0 - _panel.size.y)
	_toast_box.position = Vector2(24, 70)
	_banner.position = Vector2((vp.x - _banner.size.x) / 2.0, vp.y * 0.38)
	if _active:
		_cur_t += delta
		var left: float = _cur_dur - _cur_t
		_panel.modulate.a = clampf(left / 0.4, 0.0, 1.0)
		if left <= 0.0:
			_active = false
			current_text = ""
			_panel.visible = false
	if not _active and not _queue.is_empty():
		var m: Dictionary = _queue.pop_front()
		var txt: String = str(m["t"]).replace("[", "[lb]")
		var c: String = speaker_color(m["s"]).to_html(false)
		if str(m["s"]) == "":
			_label.text = "[center]%s[/center]" % txt
		else:
			_label.text = "[center][color=#%s][b]%s:[/b][/color] %s[/center]" % [c, m["s"], txt]
		current_text = str(m["t"])
		_cur_t = 0.0
		_cur_dur = m["d"]
		_active = true
		_panel.visible = true
		_panel.modulate.a = 1.0
	for i in range(_toasts.size() - 1, -1, -1):
		var e: Dictionary = _toasts[i]
		e["t"] -= delta
		e["l"].modulate.a = clampf(e["t"] / 0.6, 0.0, 1.0)
		if e["t"] <= 0.0:
			e["l"].queue_free()
			_toasts.remove_at(i)
	if _banner.visible:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.6, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.visible = false
