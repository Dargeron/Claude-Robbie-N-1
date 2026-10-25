shader_type canvas_item;
// The sector as the sonar paints it (Dead Air): rock is a stack of contour lines with a bright wall
// return at its edge, water a faint speckle, and nothing at all where no Robbie has listened.
// TEXTURE is the room's signed distance field (red: 128 + 2 x px, positive in water).
// `reveal` holds, per tile, the tick this Robbie first sensed it (r, g = high, low byte; 65535 =
// never) and whether earlier Robbies charted it (b).

uniform sampler2D reveal : filter_nearest;
uniform vec2 tiles = vec2(40.0, 22.0);
uniform float now_tick = 0.0;
uniform vec2 robbie = vec2(40.0, 40.0);
uniform float sweep = 0.0;
uniform float live = 1.0;          // 0 when showing the chart only
uniform vec4 phosphor : source_color = vec4(0.36, 1.0, 0.6, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// x: sensed by this Robbie by now, y: charted before, z: freshness of the return (1 = just pinged).
vec3 tile_state(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(tiles) - ivec2(1));
	vec4 s = texelFetch(reveal, c, 0);
	float first = floor(s.r * 255.0 + 0.5) * 256.0 + floor(s.g * 255.0 + 0.5);
	float seen = (first <= now_tick && live > 0.5) ? 1.0 : 0.0;
	float fresh = seen * exp(-max(now_tick - first, 0.0) / 45.0);
	return vec3(seen, s.b, fresh);
}

void fragment() {
	vec2 size = tiles * 16.0;
	vec2 px = UV * size;
	float wob = (vnoise(px * 0.06) - 0.5) * 3.0 + (vnoise(px * 0.21 + 7.0) - 0.5) * 1.2;
	float sdf = (texture(TEXTURE, UV).r * 255.0 - 128.0) * 0.5 + wob;

	vec2 tp = px / 16.0 - 0.5;
	ivec2 t0 = ivec2(floor(tp));
	vec2 f = smoothstep(0.0, 1.0, fract(tp));
	vec3 a = tile_state(t0);
	vec3 b = tile_state(t0 + ivec2(1, 0));
	vec3 c = tile_state(t0 + ivec2(0, 1));
	vec3 d = tile_state(t0 + ivec2(1, 1));
	vec3 st = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	float known = max(st.x, st.y * 0.42);

	// Rock: contour lines every 7 px, fading with depth; the wall return at the edge.
	float inside = 1.0 - smoothstep(-0.5, 0.5, sdf);
	float cdist = abs(fract((-sdf) / 7.0) - 0.5) * 7.0;
	float contour = (1.0 - smoothstep(0.55, 1.6, cdist)) * inside * exp(sdf / 40.0);
	float edge = 1.0 - smoothstep(0.4, 3.0, abs(sdf));
	float halo = (1.0 - smoothstep(0.0, 9.0, sdf)) * (1.0 - inside) * 0.2;
	// Water: a faint wash where it has been heard, and the grain of the bottom return.
	float speck = step(0.93, hash(floor(px * 0.5))) * (1.0 - inside) * 0.35;
	float wash = (1.0 - inside) * 0.06;

	// The sweep: what it just passed burns brighter, and fades round the dial.
	vec2 rel = px - robbie;
	float ang = atan(rel.y, rel.x);
	float behind = mod(sweep - ang, 6.2831853);
	float sw = mix(1.0, 0.55 + 0.7 * exp(-behind * 1.4), live);

	float lum = (edge * 1.1 + contour * 0.6 + halo + speck + wash) * known * sw;
	lum += (edge * 0.9 + contour * 0.35) * st.z;        // a fresh return flares

	// Range rings every three tiles around Robbie, and bearing spokes, faint.
	float dist = length(rel);
	float ringd = abs(mod(dist + 24.0, 48.0) - 24.0);
	float ring = (1.0 - smoothstep(0.2, 0.9, ringd)) * (1.0 - smoothstep(60.0, 260.0, dist)) * 0.16 * live;
	float spoke_a = abs(mod(ang + 3.14159265 / 12.0, 3.14159265 / 6.0) - 3.14159265 / 12.0) * dist;
	float spoke = (1.0 - smoothstep(0.2, 0.8, spoke_a)) * step(20.0, dist) * (1.0 - smoothstep(40.0, 220.0, dist)) * 0.07 * live;
	float sweep_line = (1.0 - smoothstep(0.0, 0.05, behind)) * (1.0 - smoothstep(30.0, 300.0, dist)) * 0.35 * live;

	vec3 col = phosphor.rgb * lum + phosphor.rgb * (ring + spoke + sweep_line);
	col += vec3(0.0, 0.012, 0.006);
	COLOR = vec4(col, 1.0);
}
