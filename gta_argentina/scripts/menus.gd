class_name Menus
extends CanvasLayer
## Menú de inicio, menú de pausa (Esc), controles y opciones.

signal play_requested
signal resume_requested
signal pause_requested
signal main_menu_requested
signal quit_requested
signal settings_changed

var current: String = "none"
var _root: Control
var _screens: Dictionary = {}
var _return_to: String = "start"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	add_child(_root)
	_build_start()
	_build_pause()
	_build_controls()
	_build_options()
	_show("none")

# ---------- API ----------
func open_start() -> void:
	_show("start")

func open_pause() -> void:
	_show("pause")

func close_all() -> void:
	_show("none")

func is_open() -> bool:
	return current != "none"

func _show(name: String) -> void:
	current = name
	for k in _screens:
		_screens[k].visible = (k == name)
	if name != "none":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		match current:
			"none": pause_requested.emit()
			"pause": resume_requested.emit()
			"controls", "options": _show(_return_to)
		get_viewport().set_input_as_handled()

# ---------- construcción ----------
func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 54)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _label(parent: Node, text: String, size: int, color: Color = Color(0.92, 0.95, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _full_rect(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c

func _dim(parent: Node, a: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, a)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)

func _centered_panel(parent: Node) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb

func _build_start() -> void:
	var s := _full_rect(_root)
	_screens["start"] = s
	var strip := ColorRect.new()
	strip.color = Color(0.03, 0.05, 0.08, 0.84)
	strip.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	strip.custom_minimum_size.x = 560
	strip.size.x = 560
	s.add_child(strip)
	var accent := ColorRect.new()
	accent.color = UITheme.ACCENT
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.position.x = 560
	accent.size.x = 4
	s.add_child(accent)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	m.size.x = 560
	m.add_theme_constant_override("margin_left", 60)
	m.add_theme_constant_override("margin_top", 110)
	s.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)
	_label(vb, "GTA", 84, Color.WHITE)
	_label(vb, "ARGENTINA", 64, UITheme.ACCENT)
	_label(vb, "Buenos Aires · Mundo abierto", 20, Color(0.7, 0.78, 0.86))
	var sp := Control.new()
	sp.custom_minimum_size.y = 40
	vb.add_child(sp)
	_button(vb, "JUGAR", func(): play_requested.emit())
	_button(vb, "CONTROLES", func(): _return_to = "start"; _show("controls"))
	_button(vb, "OPCIONES", func(): _return_to = "start"; _show("options"))
	_button(vb, "SALIR", func(): quit_requested.emit())
	var sp2 := Control.new()
	sp2.custom_minimum_size.y = 30
	vb.add_child(sp2)
	_label(vb, "Versión de desarrollo · Fase 4", 15, Color(0.5, 0.58, 0.66))

func _build_pause() -> void:
	var s := _full_rect(_root)
	_screens["pause"] = s
	_dim(s, 0.6)
	var vb := _centered_panel(s)
	_label(vb, "PAUSA", 48, Color.WHITE)
	_button(vb, "CONTINUAR", func(): resume_requested.emit())
	_button(vb, "CONTROLES", func(): _return_to = "pause"; _show("controls"))
	_button(vb, "OPCIONES", func(): _return_to = "pause"; _show("options"))
	_button(vb, "MENÚ PRINCIPAL", func(): main_menu_requested.emit())
	_button(vb, "SALIR DEL JUEGO", func(): quit_requested.emit())

func _build_controls() -> void:
	var s := _full_rect(_root)
	_screens["controls"] = s
	_dim(s, 0.75)
	var vb := _centered_panel(s)
	_label(vb, "CONTROLES", 44, Color.WHITE)
	var rows: Array = [
		["WASD", "Moverse"], ["Shift", "Correr"], ["Espacio", "Saltar"], ["C", "Agacharse"],
		["E", "Interactuar · hablar · subir/bajar de vehículos · agarrar al chorro"],
		["R", "Arrebatar (acción de robo: la policía puede verte)"],
		["V", "Liberar / capturar el mouse"], ["Esc", "Pausa"],
		["W / S", "Vehículo: acelerar, frenar, marcha atrás"], ["A / D", "Vehículo: girar"],
		["Espacio", "Vehículo: freno de mano (derrape)"], ["H", "Vehículo: bocina"],
		["Shift", "Bicicleta: pedalear fuerte"]]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 36)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	for r in rows:
		_label(g, r[0], 20, UITheme.ACCENT)
		_label(g, r[1], 20)
	_button(vb, "VOLVER", func(): _show(_return_to))

func _slider_row(parent: Node, text: String, minv: float, maxv: float, step: float, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	parent.add_child(h)
	var l := _label(h, text, 20)
	l.custom_minimum_size.x = 280
	var sl := HSlider.new()
	sl.min_value = minv
	sl.max_value = maxv
	sl.step = step
	sl.value = val
	sl.custom_minimum_size = Vector2(300, 28)
	sl.value_changed.connect(cb)
	h.add_child(sl)

func _check_row(parent: Node, text: String, val: bool, cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	parent.add_child(h)
	var l := _label(h, text, 20)
	l.custom_minimum_size.x = 280
	var cb2 := CheckButton.new()
	cb2.button_pressed = val
	cb2.toggled.connect(cb)
	h.add_child(cb2)

func _build_options() -> void:
	var s := _full_rect(_root)
	_screens["options"] = s
	_dim(s, 0.75)
	var vb := _centered_panel(s)
	_label(vb, "OPCIONES", 44, Color.WHITE)
	_slider_row(vb, "Volumen general", 0.0, 1.0, 0.05, GameSettings.master_volume, func(v: float): _changed(func(): GameSettings.master_volume = v))
	_slider_row(vb, "Sensibilidad del mouse", 0.3, 3.0, 0.1, GameSettings.mouse_sens_mul, func(v: float): _changed(func(): GameSettings.mouse_sens_mul = v))
	_slider_row(vb, "Distancia de dibujado", 150.0, 700.0, 50.0, GameSettings.view_distance, func(v: float): _changed(func(): GameSettings.view_distance = v))
	_check_row(vb, "Sombras", GameSettings.shadows, func(on: bool): _changed(func(): GameSettings.shadows = on))
	_check_row(vb, "Pantalla completa", GameSettings.fullscreen, func(on: bool): _changed(func(): GameSettings.fullscreen = on))
	_button(vb, "VOLVER", func(): _show(_return_to))

func _changed(setter: Callable) -> void:
	setter.call()
	GameSettings.save_settings()
	settings_changed.emit()
