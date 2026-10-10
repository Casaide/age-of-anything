extends Node2D
## A resource tile's prop: reed stalks (wood) or a bug bush (food). It thins out
## as the tile is used up. Positioned at the tile centre so it y-sorts with units.

const Iso := preload("res://src/view/iso.gd")

const REED := Color("#9aa846")
const REED_TIP := Color("#6b4a2a")
const BUSH := Color("#4e6e34")
const BUSH_DARK := Color("#3b5527")
const BUG := Color("#d65a7a")

var kind := ""
var full := 1
var left := 1
var seed_value := 0      # cosmetic jitter only


func setup(cell_x: int, cell_y: int, p_kind: String, amount: int) -> void:
	kind = p_kind
	full = amount
	left = amount
	seed_value = cell_x * 7919 + cell_y * 104729
	position = Iso.to_screen(cell_x * 1000 + 500, cell_y * 1000 + 500)


func set_left(amount: int) -> void:
	if amount != left:
		left = amount
		queue_redraw()


func _draw() -> void:
	var f := clampf(float(left) / float(full), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if kind == "wood":
		var stalks := 3 + int(round(9.0 * f))
		for k in stalks:
			var base := Vector2(rng.randf_range(-20, 20), rng.randf_range(-8, 8))
			base.x *= 1.0 - absf(base.y) / 16.0
			var top := base + Vector2(rng.randf_range(-3, 3), -rng.randf_range(16, 26))
			draw_line(base, top, REED, 2.0)
			draw_line(top, top + Vector2(0, 5), REED_TIP, 3.0)
	else:
		var r := 7.0 + 7.0 * f
		draw_circle(Vector2(0, -r * 0.6), r * 1.15, BUSH_DARK)
		draw_circle(Vector2(-r * 0.5, -r * 0.5), r * 0.8, BUSH)
		draw_circle(Vector2(r * 0.55, -r * 0.7), r * 0.75, BUSH)
		for k in 3 + int(round(5.0 * f)):
			draw_circle(Vector2(rng.randf_range(-r, r), -rng.randf_range(0, r * 1.6)), 1.6, BUG)
