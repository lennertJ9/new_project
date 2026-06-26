extends Node2D


func _draw() -> void:
	var font = ThemeDB.fallback_font

	for i in range(-2560, 2560, 256):
		for j in range(-2560, 2560, 256):
			draw_rect(
				Rect2(Vector2(i, j), Vector2(256, 256)),
				Color.RED,
				false
			)

			var chunk_coord = Vector2i(i / 256, j / 256)

			draw_string(
				font,
				Vector2(i + 10, j + 20),
				str(chunk_coord)
			)
			
			
