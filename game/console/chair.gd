class_name ChairView
extends Node3D
## View A: the console from the operator's chair. The machines are the same ones the flat view
## shows (drawn into an offscreen image, `screen_texture`); here that image is laid on the
## console's two faces in a dark room: the upright panel, and below a fold the sloping desk
## of the press and the reader's lower half, leaning towards you. A lamp hangs over it on its
## cable, swaying a little; papers and a mug lie on the desk; dust turns in the light.
## One unit is 100 console pixels; x right, y up, the upright panel's face at z = 0.

const HINGE_Y := 476.0                     # console y where the upright panel meets the slope
const SLOPE := deg_to_rad(42.0)            # how far the lower part leans out towards the chair
const W := 12.8
const SIT_POS := Vector3(6.4, -0.9, 12.2)
const SIT_AT := Vector3(6.4, -4.05, 0.7)

var screen_texture: Texture2D
var camera: Camera3D
var zoom := 0.0                            # 0 sitting back .. 1 leaning right in
var focus := SIT_AT                        # what the operator leans towards
var _lamp_pivot: Node3D
var _t := 0.0
var _down := Vector3(0, -cos(SLOPE), sin(SLOPE))      # down the slope, per unit
var _hinge := Vector3(0, -HINGE_Y / 100.0, 0)


func _ready() -> void:
	_build_environment()
	_build_console()
	_build_room()
	_build_lamp()
	_build_desk_things()
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 66.0
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	_place_camera()


func _process(delta: float) -> void:
	_t += delta
	# The lamp swings a little on its cable: the station is never quite still.
	if _lamp_pivot != null:
		_lamp_pivot.rotation = Vector3(sin(_t * 0.37) * 0.035, 0.0, sin(_t * 0.23 + 1.0) * 0.045)
	_place_camera()


# ------------------------------------------------------------------ where things are

## The point in the room where a console pixel is.
func world_point(p: Vector2) -> Vector3:
	if p.y <= HINGE_Y:
		return Vector3(p.x / 100.0, -p.y / 100.0, 0.0)
	return Vector3(p.x / 100.0, 0, 0) + _hinge + _down * ((p.y - HINGE_Y) / 100.0)


## The console pixel under a point on the screen (viewport coordinates).
func console_point(screen: Vector2) -> Vector2:
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	# The sloping face first: it stands in front of the upright one's continuation.
	var n_low := Vector3(0, sin(SLOPE), cos(SLOPE))
	var den := d.dot(n_low)
	if absf(den) > 1e-5:
		var t := (_hinge - o).dot(n_low) / den
		var hit := o + d * t
		var s := (hit - _hinge).dot(_down)
		if s >= 0.0:
			return Vector2(hit.x * 100.0, HINGE_Y + s * 100.0)
	if absf(d.z) < 1e-5:
		return Vector2(-1, -1)
	var t2 := -o.z / d.z
	var h2 := o + d * t2
	return Vector2(h2.x * 100.0, -h2.y * 100.0)


## Where a console pixel shows on the screen (for the scripted play-through).
func screen_point(p: Vector2) -> Vector2:
	return camera.unproject_position(world_point(p))


func lean(amount: float, towards: Vector2) -> void:
	zoom = clampf(amount, 0.0, 1.0)
	focus = world_point(towards.clamp(Vector2(160, 110), Vector2(1120, 650)))


func _place_camera() -> void:
	if camera == null:
		return
	var back := (SIT_POS - SIT_AT).normalized()
	var near_pos := focus + back * 4.2
	var e := zoom * zoom * (3.0 - 2.0 * zoom)
	camera.position = SIT_POS.lerp(near_pos, e)
	camera.look_at(SIT_AT.lerp(focus, e), Vector3.UP)


# ------------------------------------------------------------------ building the room

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.008, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.42, 0.42)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _panel_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D screen_tex : source_color, filter_linear;
uniform vec4 glass_rect;      // the scope's screen, in uv: it is light, not paint
uniform float self_light = 0.3;
void fragment() {
	vec3 c = texture(screen_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float glow = smoothstep(0.5, 0.9, mx) * smoothstep(0.3, 0.65, sat);
	vec2 s = step(glass_rect.xy, UV) * step(UV, glass_rect.zw);
	float scope = s.x * s.y;
	ALBEDO = c * (1.0 - self_light) * (1.0 - 0.6 * scope);
	ROUGHNESS = mix(0.62, 0.12, scope);
	SPECULAR = mix(0.16, 0.7, scope);
	EMISSION = c * (self_light + glow * 1.2 + scope * 0.75);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("screen_tex", screen_texture)
	var scr := Desk.r("screen")
	m.set_shader_parameter("glass_rect", Vector4(scr.position.x / 1280.0, scr.position.y / 720.0, scr.end.x / 1280.0, scr.end.y / 720.0))
	return m


## The console's two faces, carrying the machines' picture.
func _build_console() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v_h := HINGE_Y / 720.0
	var low := 720.0 - HINGE_Y
	var n_up := Vector3(0, 0, 1)
	var n_low := Vector3(0, sin(SLOPE), cos(SLOPE))
	var quads := [
		[Vector3(0, 0, 0), Vector3(W, 0, 0), Vector3(W, -HINGE_Y / 100.0, 0), Vector3(0, -HINGE_Y / 100.0, 0), 0.0, v_h, n_up],
		[_hinge, _hinge + Vector3(W, 0, 0), _hinge + Vector3(W, 0, 0) + _down * (low / 100.0), _hinge + _down * (low / 100.0), v_h, 1.0, n_low],
	]
	for q: Array in quads:
		var uv := [Vector2(0, q[4]), Vector2(1, q[4]), Vector2(1, q[5]), Vector2(0, q[5])]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(q[6])
			st.set_uv(uv[i])
			st.add_vertex(q[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _panel_material()
	add_child(mi)
	# The cabinet: cheeks either side, a hood over the top, proud of the faces so they sit in it.
	var low_end := _hinge + _down * (low / 100.0)
	var n2 := Vector2(sin(SLOPE), cos(SLOPE)) * 0.14     # (y, z) outwards from the slope
	var prof := PackedVector2Array([
		Vector2(0.45, -1.4), Vector2(0.45, 0.55), Vector2(0.06, 0.55), Vector2(0.06, 0.14),
		Vector2(_hinge.y + 0.08, 0.14), Vector2(low_end.y + n2.x, low_end.z + n2.y),
		Vector2(low_end.y - 0.25, low_end.z + 0.2), Vector2(-7.6, low_end.z - 0.2), Vector2(-7.6, -1.4),
	])
	var cab := _mat(Color(0.075, 0.09, 0.085), 0.55, 0.3, 9.0)
	add_child(_extrude(prof, -0.32, 0.0, cab))
	add_child(_extrude(prof, W, W + 0.32, cab))
	var hood := _box(Vector3(W + 0.64, 0.3, 1.9), Vector3(W * 0.5, 0.3, -0.4), cab)
	add_child(hood)
	# The seam where the two faces meet: a brass rail.
	add_child(_cyl(0.05, W, Vector3(W * 0.5, _hinge.y, 0.03), Vector3(0, 0, PI / 2), _mat(Color(0.42, 0.32, 0.16), 0.45, 1.0)))


func _build_room() -> void:
	# The bulkhead behind and around the console: riveted plates, sweating.
	var wall := _box(Vector3(40, 30, 0.2), Vector3(6.4, -2, -1.6), _mat(Color(0.05, 0.06, 0.06), 0.7, 0.2, 4.0))
	add_child(wall)
	var brass := _mat(Color(0.36, 0.27, 0.13), 0.5, 1.0, 14.0)
	var steel := _mat(Color(0.3, 0.32, 0.33), 0.4, 1.0, 20.0)
	# Pipes: up either side of the console, and a run across above it.
	for x: float in [-1.1, -0.75, W + 0.8]:
		add_child(_cyl(0.16 if x != -0.75 else 0.09, 30.0, Vector3(x, -2, -1.0), Vector3.ZERO, brass if x != -0.75 else steel))
	add_child(_cyl(0.2, 40.0, Vector3(6.4, 1.6, -0.9), Vector3(0, 0, PI / 2), steel))
	add_child(_cyl(0.11, 40.0, Vector3(6.4, 2.1, -1.1), Vector3(0, 0, PI / 2), brass))
	for x: float in [2.0, 6.0, 10.5]:
		add_child(_cyl(0.27, 0.16, Vector3(x, 1.6, -0.9), Vector3(0, 0, PI / 2), brass))
	# A valve wheel on the side pipe, painted red: the room's things don't work, but its valves do.
	var vw := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.2
	tor.outer_radius = 0.26
	vw.mesh = tor
	vw.material_override = _mat(Color(0.45, 0.07, 0.04), 0.4, 0.2)
	vw.position = Vector3(W + 0.8, -3.2, -0.6)
	vw.rotation = Vector3(PI / 2, 0, 0)
	add_child(vw)
	# The floor, far below in the dark.
	add_child(_box(Vector3(40, 0.2, 30), Vector3(6.4, -14.5, 6), _mat(Color(0.04, 0.04, 0.035), 0.9, 0.0, 3.0)))


func _build_lamp() -> void:
	_lamp_pivot = Node3D.new()
	_lamp_pivot.position = Vector3(6.4, 9.0, 4.4)
	add_child(_lamp_pivot)
	var drop := 7.3
	_lamp_pivot.add_child(_cyl(0.015, drop, Vector3(0, -drop * 0.5, 0), Vector3.ZERO, _mat(Color(0.02, 0.02, 0.02), 0.8, 0.0)))
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.95
	cone.height = 0.6
	cone.cap_bottom = false
	shade.mesh = cone
	var sm := _mat(Color(0.16, 0.2, 0.17), 0.5, 0.4)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = sm
	shade.position = Vector3(0, -drop - 0.3, 0)
	_lamp_pivot.add_child(shade)
	var bulb := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.16
	sp.height = 0.32
	bulb.mesh = sp
	var bm := StandardMaterial3D.new()
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.8, 0.5)
	bm.emission_energy_multiplier = 6.0
	bm.albedo_color = Color(1, 0.9, 0.7)
	bulb.material_override = bm
	bulb.position = Vector3(0, -drop - 0.45, 0)
	_lamp_pivot.add_child(bulb)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.8, 0.56)
	spot.light_energy = 13.0
	spot.spot_range = 30.0
	spot.spot_angle = 52.0
	spot.spot_angle_attenuation = 1.6
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	spot.shadow_blur = 1.5
	spot.position = Vector3(0, -drop - 0.5, 0)
	_lamp_pivot.add_child(spot)
	spot.look_at_from_position(_lamp_pivot.position + spot.position, Vector3(6.4, -4.4, 1.2), Vector3.UP)
	spot.position = Vector3(0, -drop - 0.5, 0)
	# The scope's green throws a little light of its own.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.35, 1.0, 0.6)
	glow.light_energy = 0.5
	glow.omni_range = 6.0
	glow.light_specular = 0.0
	glow.position = Vector3(3.25, -2.0, 1.2)
	add_child(glow)
	# Dust in the lamp's light.
	var dust := CPUParticles3D.new()
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(4.5, 3.5, 2.5)
	dust.position = Vector3(6.4, -2.4, 3.6)
	dust.direction = Vector3(0.2, -1, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.07
	dust.gravity = Vector3(0, -0.01, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.018)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(1.0, 0.85, 0.6, 0.35)
	q.material = dm
	dust.mesh = q
	add_child(dust)


func _build_desk_things() -> void:
	var low_end := _hinge + _down * ((720.0 - HINGE_Y) / 100.0)
	var top := low_end.y - 0.22
	# The desk: dark wood, worn pale where elbows go.
	var wood := _mat(Color(0.2, 0.12, 0.07), 0.55, 0.0, 6.0)
	add_child(_box(Vector3(W + 3.0, 0.14, 4.2), Vector3(6.4, top - 0.07, low_end.z + 2.0), wood))
	var zf := low_end.z
	# A mug, gone cold.
	var mug := _cyl(0.27, 0.6, Vector3(1.4, top + 0.3, zf + 1.3), Vector3.ZERO, _mat(Color(0.12, 0.15, 0.14), 0.35, 0.0))
	add_child(mug)
	var handle := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.1
	tor.outer_radius = 0.17
	handle.mesh = tor
	handle.material_override = mug.material_override
	handle.position = Vector3(1.12, top + 0.32, zf + 1.3)
	handle.rotation = Vector3(PI / 2, 0, PI / 2)
	add_child(handle)
	add_child(_cyl(0.24, 0.02, Vector3(1.4, top + 0.55, zf + 1.3), Vector3.ZERO, _mat(Color(0.03, 0.02, 0.01), 0.2, 0.0)))
	# Papers: carbons of old tallies, a docket.
	var paper := _mat(Color(0.6, 0.56, 0.47), 0.9, 0.0)
	for k in 3:
		var pp := _box(Vector3(1.9, 0.01, 2.5), Vector3(4.1 + k * 0.25, top + 0.006 + k * 0.006, zf + 1.6 + k * 0.1), paper)
		pp.rotation.y = 0.25 - k * 0.2
		add_child(pp)
	var dk := _box(Vector3(1.5, 0.01, 2.0), Vector3(9.6, top + 0.006, zf + 1.5), paper)
	dk.rotation.y = -0.35
	add_child(dk)
	# A pencil (yellow: it isn't part of the machine).
	var pen := _cyl(0.04, 1.3, Vector3(7.0, top + 0.04, zf + 1.1), Vector3(0, 0.6, PI / 2), _mat(Color(0.75, 0.55, 0.1), 0.5, 0.0))
	add_child(pen)


# ------------------------------------------------------------------ small builders

func _mat(c: Color, rough: float, metal: float, noise_scale := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if noise_scale > 0.0:
		# Mottling, so nothing is a clean flat colour.
		var n := NoiseTexture2D.new()
		n.width = 256
		n.height = 256
		n.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.02 * noise_scale / 6.0
		fn.fractal_octaves = 4
		n.noise = fn
		var g := Gradient.new()
		g.set_color(0, Color(0.55, 0.55, 0.55))
		g.set_color(1, Color(1.25, 1.2, 1.1))
		n.color_ramp = g
		m.albedo_texture = n
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	return m


func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	return mi


func _cyl(r: float, h: float, at: Vector3, rot: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	return mi


## A side profile (y, z) pushed out along x from x0 to x1.
func _extrude(prof: PackedVector2Array, x0: float, x1: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(prof)
	for x: float in [x0, x1]:
		for i in tris.size():
			var p := prof[tris[i]]
			st.set_normal(Vector3(-1 if x == x0 else 1, 0, 0))
			st.add_vertex(Vector3(x, p.x, p.y))
	for i in prof.size():
		var a := prof[i]
		var b := prof[(i + 1) % prof.size()]
		var e := (b - a).normalized()
		var n := Vector3(0, e.y, -e.x)
		for v: Vector3 in [Vector3(x0, a.x, a.y), Vector3(x1, a.x, a.y), Vector3(x1, b.x, b.y), Vector3(x0, a.x, a.y), Vector3(x1, b.x, b.y), Vector3(x0, b.x, b.y)]:
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	return mi
