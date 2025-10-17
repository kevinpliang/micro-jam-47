extends CharacterBody2D

enum State {
	IDLE
}
var current_state: State = State.IDLE

@export var speed: float = 400.0

func _physics_process(_delta):
	velocity = Vector2.ZERO

	if Input.is_action_pressed("right"):
		velocity.x += speed
	if Input.is_action_pressed("left"):
		velocity.x -= speed
	if Input.is_action_pressed("down"):
		velocity.y += speed
	if Input.is_action_pressed("up"):
		velocity.y -= speed

	velocity = velocity.normalized() * speed
	move_and_slide()
