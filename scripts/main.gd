extends Node2D

@export_subgroup("Properties")
@export var width: int = 8
@export var height: int = 8
@export var offset: int = 68

@export_subgroup("Scenes")
@export var tile_scene: PackedScene 
@export var sparkles_scene: PackedScene

@export_subgroup("Tiles")
@export var textures: Array[Texture2D] 

# Musical notes
const NOTES = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]

# Major chords (root, major third, perfect fifth)
const MAJOR_CHORDS = {
	"A": ["A", "C#", "E"],
	"A#": ["A#", "D", "F"],
	"B": ["B", "D#", "F#"],
	"C": ["C", "E", "G"],
	"C#": ["C#", "F", "G#"],
	"D": ["D", "F#", "A"],
	"D#": ["D#", "G", "A#"],
	"E": ["E", "G#", "B"],
	"F": ["F", "A", "C"],
	"F#": ["F#", "A#", "C#"],
	"G": ["G", "B", "D"],
	"G#": ["G#", "C", "D#"]
} 

@export_subgroup("Cursors")
@export var open_hand_cursor: Texture2D
@export var closed_hand_cursor: Texture2D

@onready var container = $Board

# State

var grid = []
var first_touch = Vector2i(-1, -1)
var is_swapping = false
var combo_count: int = 0
var hint_tiles = []

# Functions

func _ready():
	
	set_cursor(open_hand_cursor)
	
	randomize()
	
	setup_grid_array() 
	process_board_state()
	
	center_grid_on_screen() 
	
	get_viewport().size_changed.connect(center_grid_on_screen)
	
	update_hints()

# Centers the board on-screen, the above conection ensures the board is centered after resizing the window

func center_grid_on_screen():
	
	container.position = get_viewport_rect().size / 2.0 - Vector2(width - 1, height - 1) * offset / 2.0

# Initialize grid

func setup_grid_array():
	
	grid = []
	for x in width:
		grid.append([])
		grid[x].resize(height)
		grid[x].fill(null)
		
	# Spawn initial pieces
	
	for x in width:
		for y in height:
			spawn_at(x, y)

# Spawn a new tile at a certain grid position

func spawn_at(x, y):
	
	var created_piece = tile_scene.instantiate() 
	var random_note = NOTES[randi() % NOTES.size()]

	container.add_child(created_piece) 

	created_piece.set_tile_type(random_note, textures[0]) 
	created_piece.tile_pressed.connect(_on_tile_pressed) 
	created_piece.grid_position = Vector2i(x, y) 
	created_piece.position = grid_to_pixel(x, y) 

	grid[x][y] = created_piece

# Interaction

func _on_tile_pressed(grid_position: Vector2i):
	
	if not is_swapping:
		first_touch = grid_position
		set_cursor(closed_hand_cursor)

func _input(event):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if first_touch != Vector2i(-1, -1):
				var local_mouse_pos = container.get_local_mouse_position()
				calculate_swipe(local_mouse_pos)

func calculate_swipe(final_pos: Vector2):
	
	var difference = final_pos - grid_to_pixel(first_touch.x, first_touch.y)
	
	if difference.length() > 32:
		var other_touch = first_touch
		if abs(difference.x) > abs(difference.y): # Horizontal dragging
			other_touch.x += 1 if difference.x > 0 else -1
		else: # Vertical dragging
			other_touch.y += 1 if difference.y > 0 else -1
		
		if is_within_grid(other_touch):
			handle_swap_logic(first_touch, other_touch)
			Audio.play("res://sounds/tile-swap.ogg", false, randf_range(0.8, 1.2), 0.3)
	
	set_cursor(open_hand_cursor)
	first_touch = Vector2i(-1, -1)

# Game loop

func handle_swap_logic(pos_a: Vector2i, pos_b: Vector2i):
	
	is_swapping = true
	# Clear hints during swap
	for tile in hint_tiles:
		if is_instance_valid(tile):
			tile.set_hint_highlight(false)
	hint_tiles.clear()
	
	swap_pieces(pos_a, pos_b)
	
	await get_tree().create_timer(0.3).timeout
	
	if find_matches().size() > 0:
		process_board_state()
	else:
		swap_pieces(pos_a, pos_b)
		Audio.play("res://sounds/tile-swap.ogg", false, 2, 0.3)
		await get_tree().create_timer(0.3).timeout
		is_swapping = false
		update_hints()

func swap_pieces(a: Vector2i, b: Vector2i):
	
	var piece_a = grid[a.x][a.y]
	var piece_b = grid[b.x][b.y]
	
	if piece_a and piece_b:
		grid[a.x][a.y] = piece_b
		grid[b.x][b.y] = piece_a
		
		piece_a.grid_position = b
		piece_b.grid_position = a
		
		piece_a.move_to(grid_to_pixel(b.x, b.y), false)
		piece_b.move_to(grid_to_pixel(a.x, a.y), false)

func find_matches() -> Array:
	
	var matched_dict = {}

	for y in height:
		for x in range(width - 2):
			var p1 = grid[x][y]; var p2 = grid[x+1][y]; var p3 = grid[x+2][y]
			if p1 and p2 and p3 and is_major_chord(p1.type, p2.type, p3.type):
				for p in [p1, p2, p3]: matched_dict[p] = true

	for x in width:
		for y in range(height - 2):
			var p1 = grid[x][y]; var p2 = grid[x][y+1]; var p3 = grid[x][y+2]
			if p1 and p2 and p3 and is_major_chord(p1.type, p2.type, p3.type):
				for p in [p1, p2, p3]: matched_dict[p] = true

	return matched_dict.keys()

# Check if three notes form a major chord (order doesn't matter)
func is_major_chord(note1: String, note2: String, note3: String) -> bool:
	var notes = [note1, note2, note3]
	notes.sort()
	
	for chord in MAJOR_CHORDS.values():
		var chord_notes = chord.duplicate()
		chord_notes.sort()
		if notes == chord_notes:
			return true
	
	return false

# Identify which major chord is formed by the matched pieces
func identify_chord(matches: Array) -> String:
	if matches.size() < 3:
		return "C"  # Default fallback
	
	var notes = []
	for piece in matches:
		notes.append(piece.type)
	
	notes.sort()
	
	for chord_name in MAJOR_CHORDS.keys():
		var chord_notes = MAJOR_CHORDS[chord_name].duplicate()
		chord_notes.sort()
		if notes == chord_notes:
			return chord_name
	
	return "C"  # Default fallback if no match found

func process_board_state():
	
	combo_count = 0 
	var matches = find_matches()
	
	while matches.size() > 0:
		combo_count += 1
		
		# Identify which chord was matched
		var chord_name = identify_chord(matches)
		var chord_path = "res://sounds/chords/major/" + chord_name + ".mp3"
		Audio.play(chord_path, true, 1.0 + (combo_count * 0.1))
		
		for piece in matches:
			var effect = sparkles_scene.instantiate()
			effect.position = piece.position
			container.add_child(effect)
			
			grid[piece.grid_position.x][piece.grid_position.y] = null
			
			var tween = piece.create_tween()
			tween.tween_property(piece, "scale", Vector2.ZERO, 0.2)
			tween.finished.connect(piece.queue_free)
		
		await get_tree().create_timer(0.3).timeout
		await collapse_columns()
		await refill_board()
		
		matches = find_matches()
	
	is_swapping = false
	update_hints()

func collapse_columns():
	
	for x in width:
		for y in range(height - 1, -1, -1):
			if grid[x][y] == null:
				for k in range(y - 1, -1, -1):
					if grid[x][k] != null:
						grid[x][y] = grid[x][k]
						grid[x][k] = null
						grid[x][y].grid_position = Vector2i(x, y)
						grid[x][y].move_to(grid_to_pixel(x, y))
						break
	await get_tree().create_timer(0.3).timeout

func refill_board():
	
	for x in width:
		for y in height:
			if grid[x][y] == null:
				spawn_at(x, y)
				grid[x][y].position.y -= offset * 2 
				grid[x][y].move_to(grid_to_pixel(x, y))
	await get_tree().create_timer(0.3).timeout

# Utilities for coordinates

func grid_to_pixel(column: int, row: int) -> Vector2:
	
	return Vector2(offset * column, offset * row)

func is_within_grid(pos: Vector2i) -> bool:
	
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

# Hint system

func update_hints():
	# Clear existing hints
	for tile in hint_tiles:
		if is_instance_valid(tile):
			tile.set_hint_highlight(false)
	hint_tiles.clear()
	
	# Find a possible move
	var possible_move = find_possible_move()
	if possible_move:
		for tile in possible_move:
			tile.set_hint_highlight(true)
			hint_tiles.append(tile)

# Find a possible swap that would create a major chord
func find_possible_move() -> Array:
	# Check all possible adjacent swaps
	for x in width:
		for y in height:
			var current = grid[x][y]
			if not current:
				continue
			
			# Check right neighbor
			if x < width - 1:
				var right = grid[x+1][y]
				if right and would_create_match(x, y, x+1, y):
					return [current, right]
			
			# Check bottom neighbor
			if y < height - 1:
				var bottom = grid[x][y+1]
				if bottom and would_create_match(x, y, x, y+1):
					return [current, bottom]
	
	return []

# Check if swapping two positions would create a match
func would_create_match(x1: int, y1: int, x2: int, y2: int) -> bool:
	# Temporarily swap
	var temp = grid[x1][y1]
	grid[x1][y1] = grid[x2][y2]
	grid[x2][y2] = temp
	
	# Check for matches
	var has_match = find_matches().size() > 0
	
	# Swap back
	grid[x2][y2] = grid[x1][y1]
	grid[x1][y1] = temp
	
	return has_match

# Utilities

func set_cursor(cursor_texture: Texture2D):
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
