class_name DayNight
extends Node
## Ciclo día/noche: sol, luna, color del cielo, niebla, luces de calle y ventanas.

static var night: float = 0.0    # 0 = día, 1 = noche cerrada (la leen los vehículos)

var hour: float = 17.0
var minutes_per_day: float = 14.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
var lamp_mat: StandardMaterial3D

static func setup_globals() -> void:
	var names: Array = RenderingServer.global_shader_parameter_get_list()
	if not names.has(&"night"):
		RenderingServer.global_shader_parameter_add("night", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)

func _process(delta: float) -> void:
	hour = fposmod(hour + delta / (minutes_per_day * 60.0) * 24.0, 24.0)
	apply()

func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int((hour - int(hour)) * 60.0)]

func apply() -> void:
	var elev: float = sin((hour - 6.0) / 24.0 * TAU)
	var deg: float = rad_to_deg(asin(clampf(elev, -1.0, 1.0)))
	var az: float = (hour - 12.0) * 15.0 - 35.0
	sun.rotation_degrees = Vector3(-deg, az, 0)
	moon.rotation_degrees = Vector3(deg, az + 180.0, 0)
	var day: float = clampf(elev * 2.5 + 0.2, 0.0, 1.0)
	var warm: float = 1.0 - clampf(elev * 3.0, 0.0, 1.0)
	sun.light_energy = clampf(elev * 1.6, 0.0, 1.3)
	sun.light_color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.55, 0.3), warm)
	sun.visible = elev > -0.02
	moon.light_energy = 0.12 * clampf(-elev * 3.0, 0.0, 1.0)
	moon.visible = moon.light_energy > 0.001
	night = smoothstep(0.12, -0.12, elev)
	RenderingServer.global_shader_parameter_set("night", night)
	var top: Color = Color(0.02, 0.03, 0.09).lerp(Color(0.28, 0.52, 0.88), day)
	var hor: Color = Color(0.04, 0.05, 0.1).lerp(Color(0.75, 0.85, 0.95), day)
	hor = hor.lerp(Color(0.95, 0.5, 0.28), warm * day * 0.9)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor
	sky.ground_bottom_color = Color(0.1, 0.1, 0.12).lerp(Color(0.25, 0.25, 0.27), day)
	env.fog_light_color = hor
	env.ambient_light_energy = lerpf(0.25, 1.0, day)
	if lamp_mat != null:
		lamp_mat.emission_energy_multiplier = 0.05 + night * 4.0
