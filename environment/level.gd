extends Node2D

const Character = preload("res://characters/Character.tscn")

func _ready():
	_spawn_player()
		
func _spawn_player():
	var character = Character.instantiate()
	self.add_child(character)
