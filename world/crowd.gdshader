shader_type spatial;
render_mode cull_back;

uniform float clock = 0.0;
uniform float energy = 50.0;
uniform float sync = 0.5;
uniform float scatter = 0.3;
uniform float raised = 0.0;
uniform bool reduced_motion = false;
uniform int scarf_pattern = 0;
uniform vec4 primary : source_color = vec4(0.957, 0.769, 0.188, 1.0);
uniform vec4 secondary : source_color = vec4(0.114, 0.165, 0.29, 1.0);
varying float role;
varying float seat_color;
varying vec2 cloth_position;

void vertex() {
	role = COLOR.a;
	seat_color = INSTANCE_CUSTOM.g;
	cloth_position = VERTEX.xy;
	float phase = INSTANCE_CUSTOM.r * scatter * 6.283185;
	float bounce = reduced_motion ? 0.0 : max(0.0, sin(clock * 7.0 + phase)) * energy * 0.003;
	VERTEX.y += bounce;
	if (role < 0.35) {
		VERTEX.y += raised * 0.7;
	}
	if (role > 0.45 && role < 0.55) {
		VERTEX.y += raised * 0.55;
	}
}

void fragment() {
	vec3 paint = COLOR.rgb;
	if (role > 0.45 && role < 0.85) {
		paint = mix(primary.rgb, secondary.rgb, seat_color);
	}
	if (role > 0.45 && role < 0.55) {
		float alternate = mod(floor(cloth_position.x * 10.0), 2.0);
		if (scarf_pattern == 1) {
			alternate = step(0.0, cloth_position.x);
		} else if (scarf_pattern == 2) {
			alternate = mod(floor(cloth_position.x * 12.0) + floor(cloth_position.y * 12.0), 2.0);
		} else if (scarf_pattern == 3) {
			alternate = mod(floor(atan(cloth_position.y - 1.3, cloth_position.x) * 4.0), 2.0);
		} else if (scarf_pattern == 4) {
			alternate = step(1.05, cloth_position.y);
		}
		paint = mix(primary.rgb, secondary.rgb, alternate);
	}
	ALBEDO = paint;
	ROUGHNESS = 0.9;
}
