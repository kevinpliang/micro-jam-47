extends CharacterBody2D

@export var speed: float = 200.0

var baby_elephant: Node2D = null

func _ready():
	# Find the baby elephant in the scene
	baby_elephant = get_tree().get_first_node_in_group("baby_elephant")

func _physics_process(_delta):
	if baby_elephant:
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
		
	#if velocity != Vector2.ZERO:
		#$Body.play("run")
	#else:
		#$Body.play("idle")
