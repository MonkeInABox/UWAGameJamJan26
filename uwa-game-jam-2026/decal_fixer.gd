@tool extends EditorScript


func _run() -> void:
	var decal_base_node: Node = get_scene().get_node("Decals")
	print(decal_base_node)
	for decal: Decal in decal_base_node.get_children():
		decal.size.y = 0.2
		if decal.rotation_degrees.x != 0:
			# wall decal
			if decal.rotation_degrees.y == 90.0:
				# -x decal
				prints("snap -x decal", decal.name ,"from/to", decal.position, snappedf(decal.position.x, 0.5))
				decal.position.x = snappedf(decal.position.x, 0.5)
			elif decal.rotation_degrees.y == 0.0:
				# -y decal
				prints("snap -y decal", decal.name ,"from/to", decal.position, snappedf(decal.position.y, 0.5))
				decal.position.y = snappedf(decal.position.y, 0.5)
			else:
				prints("missed decal", decal.name, decal.position, decal.rotation_degrees)
