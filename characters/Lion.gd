extends CharacterBody2D

signal lion_defeated

@export var speed: float = 200.0
@onready var flipper: Node2D = $Flipper
@onready var body: AnimatedSprite2D = $Flipper/Body

var _facing := 1.0 # remembers last facing when idle
var baby_elephant: Node2D = null
var dead = false

func _ready():
	# Find the baby elephant in the scene
	baby_elephant = get_tree().get_first_node_in_group("baby_elephant")

func _physics_process(_delta):
	if baby_elephant and not dead:
		# Chase the baby elephant
		var direction = (baby_elephant.position - position).normalized()
		velocity = direction * speed
		move_and_slide()
		_change_sprite()
		
func _change_sprite():
	var desired := absf(flipper.scale.x)
	if desired == 0.0:
		desired = 1.0

	if velocity.x < -0.01:
		_facing = - desired
	elif velocity.x > 0.01:
		_facing = desired

	flipper.scale.x = _facing

	body.play("run")
			
func die():
	if dead:
		return
	dead = true
	lion_defeated.emit()
	for shape in $Flipper/Area2D.get_children():
		shape.set_deferred("disabled", true)
	$Flipper/Body.play("die")
	$AnimationPlayer.play("die")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		queue_free()

func is_defeated() -> bool:
	return dead
