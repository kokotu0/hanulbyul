extends Node
## 메뉴 화면 캡처용. godot --path . res://tests/menu_shot.tscn
func _ready() -> void:
	var m = load("res://scenes/menu.tscn").instantiate()
	add_child(m)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	get_tree().quit()
