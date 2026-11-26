class_name UITheme
extends RefCounted
## Tema visual único del juego (oscuro, minimalista, acento celeste).

const ACCENT := Color(0.46, 0.72, 0.93)

static func _sb(bg: Color, border: Color, bw: int = 2, radius: int = 6, mx: int = 18, my: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", _sb(Color(0.1, 0.13, 0.18, 0.9), Color(0.3, 0.4, 0.5, 0.8)))
	t.set_stylebox("hover", "Button", _sb(Color(0.22, 0.42, 0.62, 0.97), ACCENT))
	t.set_stylebox("pressed", "Button", _sb(Color(0.3, 0.55, 0.8, 1.0), Color.WHITE))
	t.set_stylebox("focus", "Button", _sb(Color(0.18, 0.36, 0.55, 0.97), ACCENT))
	t.set_color("font_color", "Button", Color(0.92, 0.95, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("panel", "PanelContainer", _sb(Color(0.05, 0.07, 0.1, 0.92), Color(0.3, 0.4, 0.5, 0.7), 2, 10, 28, 24))
	t.set_color("font_color", "Label", Color(0.92, 0.95, 1.0))
	return t
