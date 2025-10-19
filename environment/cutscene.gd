extends Node2D

func _ready():
	$Camera2D.make_current()
	$PlayerElephant/Label.visible_ratio = 0
	$PlayerElephant/Label1.visible_ratio = 0
	$Label2.visible_ratio = 0

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if !$AnimationPlayer.is_playing():
				$AnimationPlayer.play("remove-label")
			
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "remove-label":
		$PlayerElephant/Label.visible = false
		$Mouse.visible = false
	if anim_name == "label-1":	
		$AnimationPlayer.play("label-2")
	if anim_name == "label-2":
		Main.tutorial_played = true
		Main.load_scene("res://environment/level.tscn")

func _on_lion_tree_exited() -> void:
	$AnimationPlayer.play("label-1")
