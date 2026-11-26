class_name GameSettings
extends RefCounted
## Opciones del jugador, guardadas en user://settings.cfg (se conservan al actualizar el juego).

const PATH := "user://settings.cfg"
static var master_volume: float = 0.8
static var mouse_sens_mul: float = 1.0
static var fullscreen: bool = false
static var shadows: bool = true
static var view_distance: float = 500.0

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = cf.get_value("audio", "master", master_volume)
	mouse_sens_mul = cf.get_value("input", "mouse_sens", mouse_sens_mul)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
	shadows = cf.get_value("video", "shadows", shadows)
	view_distance = cf.get_value("video", "view_distance", view_distance)

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master_volume)
	cf.set_value("input", "mouse_sens", mouse_sens_mul)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "shadows", shadows)
	cf.set_value("video", "view_distance", view_distance)
	cf.save(PATH)

static func apply_system() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
