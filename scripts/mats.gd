class_name Mats
extends RefCounted

const TEXTURES := {
    "grain": [0.03, Color(0.84, 0.84, 0.84), Color(1, 1, 1)],
    "sand": [0.012, Color(0.76, 0.63, 0.47), Color(0.93, 0.81, 0.63)],
    "asphalt": [0.09, Color(0.13, 0.13, 0.14), Color(0.25, 0.25, 0.26)],
    "gravel": [0.3, Color(0.52, 0.44, 0.36), Color(0.8, 0.7, 0.58)],
    "grass": [0.08, Color(0.3, 0.4, 0.18), Color(0.45, 0.52, 0.25)],
    "concrete": [0.05, Color(0.6, 0.59, 0.56), Color(0.74, 0.73, 0.7)],
}
const NORMALS := {
    "stucco": [0.12, 1.2],
    "sand": [0.02, 4.0],
    "rough": [0.25, 0.8],
}

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func solid(key: String, color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
    if _mat_cache.has(key):
        return _mat_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    _mat_cache[key] = m
    return m


static func emissive(key: String, color: Color, energy := 1.0) -> StandardMaterial3D:
    if _mat_cache.has(key):
        return _mat_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = energy
    _mat_cache[key] = m
    return m


static func make(key: String, tint: Color, tex_key: String, uv_scale := 0.25, roughness := 0.9, normal_key := "") -> StandardMaterial3D:
    if _mat_cache.has(key):
        return _mat_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.albedo_texture = _albedo_tex(tex_key)
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE * uv_scale
    m.roughness = roughness
    if normal_key != "":
        m.normal_enabled = true
        m.normal_texture = _normal_tex(normal_key)
    _mat_cache[key] = m
    return m


static func _noise(freq: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.frequency = freq
    n.fractal_type = FastNoiseLite.FRACTAL_FBM
    n.fractal_octaves = 4
    return n


static func _albedo_tex(key: String) -> NoiseTexture2D:
    if _tex_cache.has("a_" + key):
        return _tex_cache["a_" + key]
    var spec: Array = TEXTURES[key]
    var t := NoiseTexture2D.new()
    t.width = 512
    t.height = 512
    t.seamless = true
    t.generate_mipmaps = true
    t.noise = _noise(spec[0])
    var g := Gradient.new()
    g.set_color(0, spec[1])
    g.set_color(1, spec[2])
    t.color_ramp = g
    _tex_cache["a_" + key] = t
    return t


static func _normal_tex(key: String) -> NoiseTexture2D:
    if _tex_cache.has("n_" + key):
        return _tex_cache["n_" + key]
    var spec: Array = NORMALS[key]
    var t := NoiseTexture2D.new()
    t.width = 512
    t.height = 512
    t.seamless = true
    t.generate_mipmaps = true
    t.noise = _noise(spec[0])
    t.as_normal_map = true
    t.bump_strength = spec[1]
    _tex_cache["n_" + key] = t
    return t
