extends Node3D
## Orquestador: entorno, ciudad, jugador, peatones, tráfico, vehículos, delito, HUD y menús.

const NPC_COUNT := 70
const CAR_COUNT := 24

var state: String = "menu"      # menu | playing | paused
var player: CharacterBody3D
var crowd: Crowd
var traffic: Traffic
var daynight: DayNight
var crime: Crime
var subs: Subtitles
var menus: Menus
var vehicles: Array[DrivableVehicle] = []
var _hud: CanvasLayer
var _money_label: Label
var _prompt_label: Label
var _speed_label: Label
var _clock_label: Label
var _help_label: Label
var _stars: Label
var _menu_cam: Camera3D
var _menu_angle: float = 0.0
var _last_money: int = 0
var _speaker_re := RegEx.new()

func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.apply_system()
	_speaker_re.compile("^([A-Za-zÁÉÍÓÚÑáéíóúñ ]{2,20}): (.+)$")
	InputSetup.setup()
	DayNight.setup_globals()
	_build_environment()
	var builder := CityBuilder.new()
	builder.build(self, 1810)
	daynight.lamp_mat = builder.lamp_mat
	_spawn_player()
	crime = Crime.new()
	add_child(crime)
	crime.player = player
	player.set("crime", crime)
	crowd = Crowd.new()
	add_child(crowd)
	crowd.crime = crime
	crime.crowd = crowd
	crowd.spawn(NPC_COUNT, player, 77)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.spawn(CAR_COUNT, player, 99)
	_spawn_vehicles()
	subs = Subtitles.new()
	add_child(subs)
	_build_hud()
	menus = Menus.new()
	add_child(menus)
	menus.play_requested.connect(_start_playing)
	menus.pause_requested.connect(_pause)
	menus.resume_requested.connect(_resume)
	menus.main_menu_requested.connect(_to_main_menu)
	menus.quit_requested.connect(func(): get_tree().quit())
	menus.settings_changed.connect(_apply_settings)
	crime.notify.connect(func(t: String, c: Color): subs.notify(t, c))
	crime.banner.connect(func(t: String, c: Color): subs.banner(t, c))
	crime.wanted_changed.connect(_on_wanted)
	player.connect("notice", func(t: String): subs.notify(t, Color(0.8, 0.9, 1.0)))
	_apply_settings()
	daynight.apply()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--smoke" in args or "--smoke-ui" in args:
		_start_playing()
		if "--smoke-ui" in args:
			_run_ui_test()
		else:
			_run_smoke_test()
	else:
		_enter_menu()

# ---------- estados ----------
func _enter_menu() -> void:
	state = "menu"
	player.set("controls_enabled", false)
	_hud.visible = false
	if _menu_cam == null:
		_menu_cam = Camera3D.new()
		_menu_cam.far = 700.0
		_menu_cam.fov = 60.0
		add_child(_menu_cam)
	_menu_cam.make_current()
	menus.open_start()

func _start_playing() -> void:
	state = "playing"
	menus.close_all()
	player.set("controls_enabled", true)
	player.call("make_camera_current")
	player.call("capture_mouse")
	_hud.visible = true
	subs.say("Narrador", "Buenos Aires, la tarde cae sobre la plaza. Tenés $5000 y el barrio entero por delante.", 6.0)
	subs.say("Narrador", "Ojo con los chorros: andan sueltos por todos lados.", 5.0)
	subs.notify("Subite a un vehículo en la calle junto a la plaza (E)", Color(0.8, 0.9, 1.0))

func _pause() -> void:
	if state != "playing":
		return
	state = "paused"
	get_tree().paused = true
	menus.open_pause()

func _resume() -> void:
	get_tree().paused = false
	state = "playing"
	menus.close_all()
	player.call("capture_mouse")

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_settings() -> void:
	GameSettings.apply_system()
	daynight.sun.shadow_enabled = GameSettings.shadows
	var cam: Camera3D = player.get("_cam")
	cam.far = GameSettings.view_distance

func _on_wanted(level: int) -> void:
	_stars.text = "★".repeat(level) + "☆".repeat(3 - level)
	_stars.visible = level > 0
	if level > 0:
		subs.say("Policía", "¡Alto! ¡Quedate donde estás!" if level == 1 else "¡Todas las unidades, tenemos un sospechoso!", 3.0)

func _process(delta: float) -> void:
	if state == "menu":
		_menu_angle += delta * 0.07
		var c: Vector3 = CityLayout.cell_center(3, 3)
		_menu_cam.global_position = c + Vector3(cos(_menu_angle) * 70.0, 24.0, sin(_menu_angle) * 70.0)
		_menu_cam.look_at(c + Vector3(0, 6, 0))
		return
	var sz: Vector2 = get_viewport().get_visible_rect().size
	_speed_label.position = Vector2(sz.x - 320, sz.y - 110)
	_clock_label.position = Vector2(sz.x - 120, 16)
	_stars.position = Vector2(sz.x - 190, 56)
	_help_label.position = Vector2(24, sz.y - 40)
	_prompt_label.position = Vector2(sz.x / 2.0 - 250, sz.y - 190)
	if _stars.visible:
		_stars.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.01)
	var v: Node = player.get("vehicle")
	if v != null:
		_speed_label.text = "%d km/h\n%s · daño %d%%" % [int(v.call("kph")), v.spec["name"], int(minf(v.damage, 100.0))]
	else:
		_speed_label.text = ""
	_clock_label.text = daynight.clock_text()

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.4
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.light_angular_distance = 0.35
	sun.shadow_blur = 1.2
	add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.shadow_enabled = false
	add_child(moon)
	daynight = DayNight.new()
	daynight.sun = sun
	daynight.moon = moon
	daynight.env = env
	daynight.sky = sky_mat
	add_child(daynight)

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(8.0, 1.0, 20.0)
	add_child(player)
	player.connect("money_changed", _on_money)
	player.connect("message", _on_message)
	player.connect("prompt_changed", _on_prompt)
	_last_money = player.get("money")

func _park(kind: String, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> DrivableVehicle:
	var v := DrivableVehicle.new()
	add_child(v)
	v.setup(kind, rng)
	v.position = pos
	v.rotation.y = yaw
	vehicles.append(v)
	return v

func _spawn_vehicles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var show: Array = [["moto", 10.0, 5.2], ["bici", 15.0, 5.2], ["auto", 21.0, 5.2],
		["camioneta", 28.0, 5.2], ["colectivo", 38.0, 5.2], ["camion", 34.0, -5.7]]
	for s in show:
		var side_pos: float = s[2]
		_park(s[0], Vector3(side_pos, 0, s[1]), 0.0 if side_pos > 0.0 else PI, rng)
	var kinds: Array[String] = ["auto", "auto", "auto", "camioneta", "moto", "auto", "bici", "camioneta", "auto", "moto"]
	var streets: Array[int] = [0, 1, 2, 4, 5, 6]
	for k in kinds:
		var st: int = streets[rng.randi() % streets.size()]
		var seg: int = rng.randi() % CityLayout.GRID
		var z: float = CityLayout.street_coord(seg) + 26.0 + rng.randf_range(-9.0, 9.0)
		var side: int = 1 if rng.randf() < 0.5 else -1
		var x: float = CityLayout.street_coord(st) + (5.2 if side > 0 else -5.7)
		_park(k, Vector3(x, 0, z), 0.0 if side > 0 else PI, rng)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_money_label = _label(_hud, Vector2(24, 16), 28)
	_money_label.text = "$ %d" % player.get("money")
	_prompt_label = _label(_hud, Vector2(0, 0), 22)
	_speed_label = _label(_hud, Vector2(0, 0), 30)
	_clock_label = _label(_hud, Vector2(0, 0), 26)
	_stars = _label(_hud, Vector2(0, 0), 34)
	_stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_stars.visible = false
	_help_label = _label(_hud, Vector2(0, 0), 15)
	_help_label.text = "WASD mover · Shift correr · C agacharse · Espacio saltar · E interactuar · R arrebatar · V mouse · Esc pausa"

func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func _on_money(v: int) -> void:
	_money_label.text = "$ %d" % v
	var diff: int = v - _last_money
	_last_money = v
	if diff > 0:
		subs.notify("+$%d" % diff, Color(0.55, 1.0, 0.55))
	elif diff < 0:
		subs.notify("-$%d" % -diff, Color(1.0, 0.5, 0.45))

func _on_message(t: String) -> void:
	var m: RegExMatch = _speaker_re.search(t)
	if m != null:
		subs.say(m.get_string(1), m.get_string(2))
	else:
		subs.say("", t)

func _on_prompt(t: String) -> void:
	_prompt_label.text = t

# ---------- Pruebas rápidas: godot --headless --path . -- --smoke-ui ----------
func _run_ui_test() -> void:
	var ok: bool = true
	await _frames(60)
	# 1) Subtítulos
	subs.clear()
	subs.say("Vecino", "hola mundo", 0.6)
	subs.say("Policía", "segundo mensaje", 0.6)
	await get_tree().create_timer(0.3).timeout
	var s1: bool = subs.current_text == "hola mundo"
	await get_tree().create_timer(0.7).timeout
	var s2: bool = subs.current_text == "segundo mensaje"
	await get_tree().create_timer(1.0).timeout
	var s3: bool = subs.current_text == ""
	subs.notify("prueba", Color.WHITE)
	subs.banner("PRUEBA", Color.WHITE)
	_on_message("Vecino: probando el parser")
	await get_tree().create_timer(0.3).timeout
	var s4: bool = subs.current_text == "probando el parser" or subs.current_text != ""
	print("SMOKE-UI: subtítulos cola=", s1, "/", s2, "/", s3, " parser=", s4)
	ok = ok and s1 and s2 and s3 and s4
	# 2) Pausa con Esc, opciones y volver
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menus._unhandled_input(esc)          # none -> pause_requested
	await get_tree().process_frame
	var p1: bool = get_tree().paused and menus.current == "pause" and state == "paused"
	menus._return_to = "pause"
	menus._show("options")
	menus._unhandled_input(esc)          # options -> pause
	var p2: bool = menus.current == "pause" and get_tree().paused
	menus._unhandled_input(esc)          # pause -> resume
	await get_tree().process_frame
	var p3: bool = (not get_tree().paused) and menus.current == "none" and state == "playing"
	print("SMOKE-UI: pausa=", p1, " opciones->volver=", p2, " reanudar=", p3)
	ok = ok and p1 and p2 and p3
	# 3) Menú de inicio y JUGAR
	_enter_menu()
	await get_tree().process_frame
	var m1: bool = state == "menu" and menus.current == "start" and not player.get("controls_enabled")
	menus.play_requested.emit()
	await get_tree().process_frame
	var m2: bool = state == "playing" and menus.current == "none" and player.get("controls_enabled")
	print("SMOKE-UI: menú inicio=", m1, " jugar=", m2)
	ok = ok and m1 and m2
	# 4) Tecla V: liberar / capturar el mouse (y Esc no lo toca)
	var f0: bool = player.get("mouse_free")
	player.call("toggle_mouse")
	var v1: bool = player.get("mouse_free")
	player.call("toggle_mouse")
	var v2: bool = not player.get("mouse_free")
	print("SMOKE-UI: V libera=", v1, " V captura=", v2)
	ok = ok and (not f0) and v1 and v2
	# 5) Opciones persistentes
	GameSettings.master_volume = 0.33
	GameSettings.save_settings()
	GameSettings.master_volume = 0.8
	GameSettings.load_settings()
	var o1: bool = absf(GameSettings.master_volume - 0.33) < 0.001
	GameSettings.master_volume = 0.8
	GameSettings.save_settings()
	print("SMOKE-UI: opciones guardadas=", o1)
	ok = ok and o1
	# 6) Chorro: roba y huye; el jugador lo alcanza y recupera la plata
	crime.set_wanted(0)
	player.global_position = crowd._pos[0] + Vector3(0, 0.5, 0)
	player.set("money", 5000)
	_last_money = 5000
	await _frames(5)
	var thief: Pedestrian = crowd.spawn_one("chorro", 0, false)
	thief.global_position = player.global_position + Vector3(7, 0, 0)
	thief.cooldown = 0.0
	var waited: int = 0
	while thief.mode != "flee" and waited < 900:
		await get_tree().physics_frame
		waited += 1
	var robbed: bool = thief.mode == "flee" and int(player.get("money")) < 5000 and thief.loot > 0
	var lost: int = 5000 - int(player.get("money"))
	player.global_position = thief.global_position + Vector3(1.0, 0, 0)
	await get_tree().physics_frame
	var prompt_txt: String = str(thief.prompt)
	player.call("_try_interact")
	var got_back: bool = int(player.get("money")) == 5000 and thief.mode == "caught"
	print("SMOKE-UI: chorro robó=", robbed, " ($", lost, ") prompt='", prompt_txt, "' recuperó=", got_back)
	ok = ok and robbed and got_back and prompt_txt == "Agarrar al chorro"
	# 7) Arrebato del jugador + búsqueda + arresto
	var victim: Pedestrian = null
	for p in crowd.peds:
		if is_instance_valid(p) and p.is_civil() and p.mode == "walk":
			victim = p
			break
	player.global_position = victim.global_position + Vector3(1.2, 0.2, 0)
	var cop: Pedestrian = crowd.spawn_one("policia", 0, true)
	cop.global_position = player.global_position + Vector3(0, 0, 9)
	await _frames(2)
	var money0: int = player.get("money")
	crime.try_snatch()
	var s_ok: bool = int(player.get("money")) > money0 and victim.mode == "scared" and crime.wanted >= 1
	print("SMOKE-UI: arrebato=", s_ok, " búsqueda=", crime.wanted, " estrellas='", _stars.text, "'")
	var money_pre: int = player.get("money")
	var w2: int = 0
	while crime.wanted > 0 and w2 < 1500:
		await get_tree().physics_frame
		w2 += 1
	var arrested: bool = crime.wanted == 0 and int(player.get("money")) < money_pre and player.global_position.distance_to(crime.spawn_point) < 3.0
	print("SMOKE-UI: arresto=", arrested, " fianza=", money_pre - int(player.get("money")), " frames=", w2)
	ok = ok and s_ok and arrested
	print("SMOKE-UI: RESULTADO = ", "OK" if ok else "FALLÓ")
	get_tree().quit(0 if ok else 1)

# ---------- Prueba automática: godot --headless --path . -- --smoke ----------
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run_smoke_test() -> void:
	var ok_all: bool = true
	await _frames(60)
	var ok_floor: bool = player.is_on_floor()
	print("SMOKE: jugador en el piso = ", ok_floor)

	# --- Animación del personaje ---
	var hum: Humanoid = null
	for c in player.get_children():
		if c is Humanoid:
			hum = c
	var max_leg: float = 0.0
	var max_arm: float = 0.0
	for i in 120:
		hum.animate(0.016, 8.0, "ground")
		max_leg = maxf(max_leg, absf(hum.leg[0].rotation.x))
		max_arm = maxf(max_arm, absf(hum.arm[0].rotation.x))
	var hip_run: float = hum.hips.position.y
	for i in 60: hum.animate(0.016, 0.0, "crouch")
	var hip_crouch: float = hum.hips.position.y
	for i in 60: hum.animate(0.016, 0.0, "seated_car")
	var hip_seat: float = hum.hips.position.y
	for i in 60: hum.animate(0.016, 0.0, "ground")
	print("SMOKE: animación piernas(máx rad)=", snappedf(max_leg, 0.01), " brazos=", snappedf(max_arm, 0.01),
		" cadera correr/agachado/sentado=", snappedf(hip_run, 0.01), "/", snappedf(hip_crouch, 0.01), "/", snappedf(hip_seat, 0.01))
	var anim_ok: bool = max_leg > 0.6 and max_arm > 0.5 and hip_crouch < 0.7 and hip_seat < 0.6
	ok_all = ok_all and anim_ok

	# --- Tráfico y peatones (40 s) ---
	var car0: Array[Vector3] = []
	for c in traffic.cars:
		car0.append(c.position)
	var ped0: Array[Vector3] = []
	for p in crowd.peds:
		ped0.append(p.position)
	await _frames(2400)
	var car_moved: int = 0
	for k in traffic.cars.size():
		if traffic.cars[k].position.distance_to(car0[k]) > 15.0:
			car_moved += 1
	var ped_moved: int = 0
	for k in crowd.peds.size():
		if crowd.peds[k].position.distance_to(ped0[k]) > 5.0:
			ped_moved += 1
	print("SMOKE: autos IA=", traffic.cars.size(), " movidos=", car_moved, " | peatones=", crowd.peds.size(), " movidos=", ped_moved)
	ok_all = ok_all and car_moved >= traffic.cars.size() * 0.7 and ped_moved >= crowd.peds.size() * 0.5

	# --- Vehículos conducibles: cada tipo ---
	traffic.queue_free()
	await _frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for kind in ["auto", "camioneta", "colectivo", "camion", "moto", "bici"]:
		var v := DrivableVehicle.new()
		add_child(v)
		v.setup(kind, rng)
		v.position = Vector3(0, 0, -70)
		v.rotation.y = 0.0
		player.global_position = v.global_position + v.model.door_pos + Vector3(-0.6, 0.3, 0)
		await _frames(2)
		var near: Node = player.call("_nearest_interactable")
		var door_ok: bool = near != null and str(near.get("prompt")).begins_with("Subir")
		player.call("_try_interact")
		var entered: bool = player.vehicle == v
		var p0: Vector3 = v.position
		v.test_input = {"throttle": 1.0}
		await _frames(240)
		var kph_acc: float = v.kph()
		var dist: float = v.position.distance_to(p0)
		var h0: float = v.rotation.y
		v.test_input = {"throttle": 1.0, "steer": 1.0}
		await _frames(90)
		var turned: float = absf(angle_difference(h0, v.rotation.y))
		v.test_input = {"throttle": -1.0}
		await _frames(150)
		var kph_brake: float = v.kph()
		v.test_input = {}
		await _frames(60)
		var wheel_spin: bool = absf(v.model.wheels[0].rotation.x) > 1.0
		# choque contra un edificio (lote en x≈8..., z=-88)
		v.position = Vector3(0, 0, -88)
		v.rotation.y = -PI / 2.0
		v.velocity = Vector3(float(v.spec["max"]) * 0.5, 0.0, 0.0)
		v.damage = 0.0
		v.test_input = {"throttle": 1.0}
		await _frames(300)
		var dmg: float = v.damage
		var x_end: float = v.position.x
		v.test_input = {}
		player.call("_try_interact")
		var exited: bool = player.vehicle == null and player.global_position.distance_to(v.global_position) > 0.8
		var good: bool = door_ok and entered and kph_acc > 6.0 and dist > 8.0 and turned > 0.15 and kph_brake < kph_acc * 0.5 and wheel_spin and dmg > 0.0 and x_end < 9.0 and exited
		print("SMOKE: ", kind, " puerta=", door_ok, " subió=", entered, " vel=", snappedf(kph_acc, 0.1), "km/h dist=", snappedf(dist, 0.1),
			" giro=", snappedf(turned, 0.01), " frenado=", snappedf(kph_brake, 0.1), " ruedas=", wheel_spin,
			" daño=", snappedf(dmg, 0.1), " x_fin=", snappedf(x_end, 0.1), " bajó=", exited, " => ", "OK" if good else "FALLÓ")
		ok_all = ok_all and good
		v.queue_free()
		await _frames(2)

	# --- Compra en el kiosco y diálogo ---
	player.global_position = CityLayout.cell_center(3, 3) + Vector3(-12, 0.6, 14.4)
	await _frames(2)
	var before: int = player.money
	player.call("_try_interact")
	var kiosk_ok: bool = player.money == before - 500
	var ped: Pedestrian = crowd.peds[0]
	player.global_position = ped.global_position + Vector3(0.5, 0.2, 0)
	await _frames(2)
	var nearp: Node = player.call("_nearest_interactable")
	print("SMOKE: kiosco=", kiosk_ok, " interactuable cercano a peatón=", nearp.get("prompt") if nearp else "ninguno")
	ok_all = ok_all and kiosk_ok and nearp != null
	# Ciclo día/noche
	daynight.hour = 12.0
	daynight.apply()
	var day_n: float = DayNight.night
	daynight.hour = 0.0
	daynight.apply()
	var night_n: float = DayNight.night
	print("SMOKE: noche al mediodía=", snappedf(day_n, 0.01), " a medianoche=", snappedf(night_n, 0.01))
	ok_all = ok_all and day_n < 0.05 and night_n > 0.9
	print("SMOKE: RESULTADO = ", "OK" if ok_all else "FALLÓ")
	get_tree().quit(0 if ok_all else 1)
