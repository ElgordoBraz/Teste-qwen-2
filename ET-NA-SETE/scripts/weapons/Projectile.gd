# Projectile - projeteis de gosma acida dos atiradores (Area3D).
extends Area3D

var direction := Vector3(0,0,-1)
var speed := 14.0
var damage := 12.0
var traveled := 0.0
var max_dist := 30.0
var is_acid := true
var mesh: MeshInstance3D

func _ready():
collision_layer = 32          # camada Projectiles
collision_mask = 1+2          # colide com mundo e player
monitoring = true
var cs := CollisionShape3D.new()
var sp := SphereShape3D.new(); sp.radius = 0.22
cs.shape = sp; add_child(cs)
mesh = MeshInstance3D.new()
var sm := SphereMesh.new(); sm.radius=0.24; sm.height=0.48
var m := StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
m.emission_enabled=true; m.emission=Color("#39FF14"); m.albedo_color=Color("#7ED92B")
mesh.mesh=sm; mesh.material_override=m; add_child(mesh)
body_entered.connect(_on_hit)
area_entered.connect(_on_area_hit)

func setup(dmg:float, col:Color, spd:float, dist:float)->void:
damage=dmg; speed=spd; max_dist=dist
if is_instance_valid(mesh):
mesh.material_override.emission = col

func _physics_process(delta):
var step := direction * speed * delta
global_position += step
traveled += step.length()
if traveled > max_dist:
_destroy(false)

func _on_hit(node:Node3D):
if node.is_in_group("Player"):
GameState.damage_player(damage)
Effects.acid_splash(global_position)
Audio.play_at("impact_flesh", global_position, -4.0)
_destroy(true)
elif node.has_meta("BreakableMine") or node.has_meta("BreakableTower"):
node.set("hp", node.get("hp") - damage)
if node.get("hp") <= 0: node.queue_free()
_destroy(true)
else:
Effects.acid_splash(global_position)
_destroy(not node.is_in_group("Enemies"))

func _on_area_hit(area:Area3D):
pass

func _destroy(did_hit:bool):
set_physics_process(false)
Audio.play_at("acid_shoot", global_position, -10.0) if not did_hit else null
queue_free()
