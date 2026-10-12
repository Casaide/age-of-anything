extends Control
## Over an army stage while its army is being made: a smoky dark veil with warm light passing
## across it, like a forge's glow, and a line of words ("Forging the army..."). Shown while a
## race is typed, rolled or baked, so a stage never shows old art without a sign.
## show_veil() / hide_veil() fade it; mouse passes through.

const Style := preload("res://src/view/loaders/loader_style.gd")

const SHADER := """
shader_type canvas_item;
uniform float t = 0.0;
uniform float strength = 1.0;
uniform vec4 glow : source_color = vec4(0.95, 0.72, 0.32, 1.0);
void fragment() {
	vec2 uv = UV;
	// The veil: darker at the edges, a little smoke drifting.
	float smoke = 0.5 + 0.5 * sin(uv.x * 9.0 + t * 0.9 + sin(uv.y * 7.0 - t * 0.6) * 1.6);
	float edge = smoothstep(0.0, 0.5, min(min(uv.x, 1.0 - uv.x) * 1.4, min(uv.y, 1.0 - uv.y) * 2.0));
	float dark = 0.5 + 0.12 * smoke - 0.1 * edge;
	// The glow: a soft slanted band sweeping across every 2.2 seconds.
	float x = uv.x + (uv.y - 0.5) * 0.35;
	float p = fract(t / 2.2) * 1.8 - 0.4;
	float band = exp(-pow((x - p) / 0.12, 2.0));
	COLOR = mix(vec4(0.03, 0.02, 0.01, dark), vec4(glow.rgb, 0.3), band * 0.85);
	COLOR.a *= strength;
}
"""

var words: Label
var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_rect.material = _mat
	add_child(_rect)
	words = Style.label("Forging the army...", Style.BODY + 5, Style.GOLD.lightened(0.35), 8)
	words.set_anchors_preset(Control.PRESET_CENTER)
	words.grow_horizontal = Control.GROW_DIRECTION_BOTH
	words.grow_vertical = Control.GROW_DIRECTION_BOTH
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(words)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("t", _t)
	words.modulate.a = 0.88 + 0.12 * sin(_t * 3.0)   # the words breathe


func show_veil(text := "Forging the army...") -> void:
	words.text = text
	visible = true
	_fade(1.0, 0.15)


func hide_veil() -> void:
	_fade(0.0, 0.3)


func _fade(to: float, secs: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to, secs)
	if to == 0.0:
		_tween.tween_callback(func(): visible = false)
