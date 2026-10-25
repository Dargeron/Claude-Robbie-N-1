shader_type canvas_item;
// The receiver's tube: a curved green phosphor screen with bloom, scanlines, grain, a slow roll bar,
// the odd tear, rounded corners, and static when the carrier drops (dead air).

uniform vec2 screen_px = vec2(596.0, 335.0);   // the size it is shown at, for the corners and lines
uniform float curvature = 0.07;
uniform float corner_px = 22.0;
uniform float dead = 0.0;                      // 0..1: static over everything
uniform float noise_amount = 0.05;
uniform float power = 1.0;                     // 0 off .. 1 on (warming up / magnify flash)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv *= 1.0 + curvature * (uv.yx * uv.yx);
	vec2 tuv = uv * 0.5 + 0.5;
	float t = TIME;

	// A rare tear: a band of rows slips sideways for a moment.
	float slot = floor(t * 3.0);
	float tear_on = step(0.97, hash(vec2(slot, 1.7)));
	float band_y = hash(vec2(slot, 4.1));
	float in_band = step(abs(tuv.y - band_y), 0.025) * tear_on;
	tuv.x += in_band * (hash(vec2(slot, 9.3)) - 0.5) * 0.04;

	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 c = texture(TEXTURE, tuv).rgb;
	vec3 glow = vec3(0.0);
	vec3 wide = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a));
		glow += texture(TEXTURE, tuv + d * px * 2.5).rgb;
		wide += texture(TEXTURE, tuv + d * px * 9.0).rgb;
	}
	c += glow / 8.0 * 0.55 + wide / 8.0 * 0.45;

	// Scanlines at the shown size, a slow roll bar, flicker and grain.
	float line = 0.8 + 0.2 * sin(tuv.y * screen_px.y * 3.14159);
	c *= line;
	float roll = fract(t * 0.07);
	c *= 1.0 + 0.07 * (1.0 - smoothstep(0.0, 0.08, abs(tuv.y - roll)));
	c *= 0.97 + 0.03 * sin(t * 61.0);
	float g = hash(floor(tuv * screen_px) + fract(t * 13.0) * 100.0);
	c += (g - 0.5) * noise_amount * vec3(0.6, 1.0, 0.7);

	// Dead air: the picture drowns in static.
	float stat = hash(floor(tuv * screen_px * 0.5) + floor(t * 40.0) * 3.1);
	vec3 snow = vec3(0.35, 0.75, 0.45) * stat * 0.55;
	c = mix(c, snow, dead * 0.88);

	// The glass: vignette, a faint reflection from the work lamp, rounded corners.
	c *= 1.0 - 0.38 * pow(dot(uv, uv) * 0.5, 1.4);
	float refl = smoothstep(0.65, 0.0, length((tuv - vec2(0.22, 0.12)) * vec2(1.0, 1.8)));
	c += vec3(0.05, 0.07, 0.06) * refl;
	vec2 sp = tuv * screen_px;
	vec2 q = abs(sp - screen_px * 0.5) - (screen_px * 0.5 - corner_px);
	float dist = length(max(q, vec2(0.0))) - corner_px;
	float mask = 1.0 - smoothstep(-1.0, 0.5, dist);
	c *= power;
	COLOR = vec4(c * mask, 1.0);
}
