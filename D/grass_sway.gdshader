shader_type canvas_item;

// Grass sway: pixels lean around the base of the sprite. UV origin is the
// top-left, so y=0 is the top of the grass (the tip) and y=1 is the base.
// The tip sways the most; the base stays planted.

uniform float sway_amount : hint_range(0.0, 0.5) = 0.1;
uniform float sway_speed : hint_range(0.0, 6.0) = 2.0;
uniform float sway_phase : hint_range(0.0, 6.2832) = 0.0;

void fragment() {
	// y=0 is the tip, y=1 is the base. Distance from the base: 0 at the base,
	// 1 at the tip.
	float from_base = 1.0 - UV.y;

	// Gentle wind: primary wave plus a slower secondary for irregularity.
	float t = TIME * sway_speed + sway_phase;
	float bend = (sin(t) * 0.6 + sin(t * 0.5 + 1.3) * 0.4) * sway_amount;
	float offset = bend * from_base * from_base;

	vec2 uv = UV;
	uv.x += offset;
	COLOR = texture(TEXTURE, uv) * COLOR;
}