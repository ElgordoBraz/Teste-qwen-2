# Effects - Autoload: particulas estilizadas (gosma, sangue/cartoon, faiscas, tracers, explosao).
extends Node

var _rng := RandomNumberGenerator.new()

func _ready():
pass

func _particles(pos:Vector3, color:Color, n:int, speed:float, life:float, gravity:float, size:float)->void:
var p := CPUParticles3D.new()
p.amount = n; p.lifetime = life; p.one_shot = true; p.emitting = true
p.explosiveness = 0.9
p.direction = Vector3(0,1,0)
p.spread = 55.0
p.initial_velocity_min = speed*0.6; p.initial_velocity_max = speed
p.gravity = Vector3(0,-gravity,0)
p.scale_amount_min = size*0.5; p.scale_amount_max = size
p.color = color
var m := StandardMaterial3D.new()
m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
m.vertex_color_use_as_albedo = true
m.albedo_color = color
p.material_override = m
add_child(p); p.global_position = pos
p.finished.connect(p.queue_free)
get_tree().create_timer(life+0.6).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func goo_splat(pos:Vector3)->void:
_particles(pos, Color("#00E5FF"), 8, 3.2, 0.55, 9.0, 0.07)
_particles(pos, Color("#7ED92B"), 6, 2.4, 0.5, 9.0, 0.06)

func blood_splat(pos:Vector3)->void:
# sangue estilizado quadrinhos: gotas vermelhas escuras
_particles(pos, Color("#B3261E"), 10, 3.6, 0.6, 10.0, 0.07)

func spark(pos:Vector3)->void:
_particles(pos, Color("#FFD700"), 5, 2.6, 0.3, 6.0, 0.045)

func explosion_fx(pos:Vector3)->void:
_particles(pos, Color("#FF8C00"), 26, 7.0, 0.8, 8.0, 0.16)
_particles(pos, Color("#FFEB00"), 14, 5.0, 0.5, 4.0, 0.12)
_particles(pos, Color("#3A3A3A"), 12, 3.0, 1.0, 2.0, 0.1)

func tracer(a:Vector3,b:Vector3)->void:
var im := ImmediateMesh.new()
im.surface_begin(Mesh.PRIMITIVE_LINES)
im.surface_add_vertex(a); im.surface_add_vertex(b)
im.surface_end()
var mi := MeshInstance3D.new(); mi.mesh = im
var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
m.emission_enabled = true; m.emission = Color(1,0.9,0.4); m.albedo_color = Color(1,0.85,0.3)
mi.material_override = m
add_child(mi); mi.global_position = Vector3.ZERO
get_tree().create_timer(0.06).timeout.connect(mi.queue_free)

func acid_splash(pos:Vector3)->void:
_particles(pos, Color("#39FF14"), 10, 2.6, 0.5, 9.0, 0.08)
