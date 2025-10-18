extends CharacterBody2D

@export var speed: float = 200.0

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
	if velocity.x < 0:
		$Body.flip_h = true
	elif velocity.x > 0:
		$Body.flip_h = false
		
	if velocity != Vector2.ZERO:
		$Body.play("run")
		
func die():
	dead = true
	$Body.play("die")
	$AnimationPlayer.play("die")
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		queue_free()
