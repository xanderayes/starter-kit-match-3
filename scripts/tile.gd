extends Area2D

signal tile_pressed(pos)

var type:String
var grid_position:Vector2i
var is_hinted: bool = false

# Highlight tile when hovering mouse

func _on_mouse_entered():
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(1.1, 1.1), 0.1)
	if is_hinted:
		tween.tween_property($Sprite2D, "modulate", Color(1.8, 1.8, 0.8), 0.1) # Brighter yellow
	else:
		tween.tween_property($Sprite2D, "modulate", Color(1.2, 1.2, 1.2), 0.1) # Brighten

# Return to default state when mouse exits

func _on_mouse_exited():
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.1)
	if is_hinted:
		tween.tween_property($Sprite2D, "modulate", Color(1.5, 1.5, 0.5), 0.1) # Yellow tint
	else:
		tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.1)

# Set piece them when initializing

func set_tile_type(note_name: String, texture: Texture2D):
	
	type = note_name
	$NoteLabel.text = note_name

# Highlight tile as a hint
func set_hint_highlight(enabled: bool):
	is_hinted = enabled
	if enabled:
		$Sprite2D.modulate = Color(1.5, 1.5, 0.5) # Yellow tint
	else:
		$Sprite2D.modulate = Color(1, 1, 1)

# Letting the main code know when a tile has been pressed

func _input_event(_viewport, event, _shape_idx):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tile_pressed.emit(grid_position)

# Animations when tile is moving

func move_to(target_position: Vector2, play_sound: bool = true):
	
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(self, "position", target_position, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	$Sprite2D.scale = Vector2(1.2, 0.8)
	tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if play_sound:
		tween.finished.connect(_on_move_finished)

# Audio that plays after the tile lands on the board

func _on_move_finished():
	
	Audio.play("res://sounds/tile-land.ogg", false, 1.2 - (grid_position.y * 0.05), 0.2)
