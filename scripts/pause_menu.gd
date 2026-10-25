extends CanvasLayer

const InterfaceTheme := preload("res://scripts/interface_theme.gd")

func _ready() -> void:
	$CenterContainer.theme = InterfaceTheme.create()
	
	
	var identity: VBoxContainer = $CenterContainer/Panel/Margin/Columns/Identity
	var settings: VBoxContainer = $CenterContainer/Panel/Margin/Columns/Settings
	for child in identity.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("e9e2d4"))
	var eyebrow := identity.get_node_or_null("Eyebrow") as Label
	if eyebrow != null:
		eyebrow.add_theme_color_override("font_color", Color("009b88"))
	var shortcut := identity.get_node_or_null("Shortcut") as Label
	if shortcut != null:
		shortcut.add_theme_color_override("font_color", Color("9aa39b"))
	for child in settings.get_children():
		if child is CheckButton:
			child.add_theme_color_override("font_color", Color("e9e2d4"))
		child.add_theme_color_override("font_hover_color", Color("009b88"))
	var resume: Button = $CenterContainer/Panel/Margin/Columns/Settings/ResumeButton
	resume.add_theme_stylebox_override("normal", _box(Color("009b88"), Color("009b88"), 8))
	resume.add_theme_stylebox_override("hover", _box(Color("6ea16e"), Color("6ea16e"), 8))
	resume.add_theme_color_override("font_color", Color("202522"))
	resume.add_theme_color_override("font_hover_color", Color("202522"))
	resume.add_theme_color_override("font_focus_color", Color("202522"))
	for name in ["MainMenuButton", "QuitButton"]:
		var button := settings.get_node(name) as Button
		button.add_theme_stylebox_override("normal", _box(Color("191d1c"), Color("38403b"), 7))
		button.add_theme_stylebox_override("hover", _box(Color("415d99"), Color("009b88"), 7))
		button.add_theme_color_override("font_color", Color("d8d2c6"))
		button.add_theme_color_override("font_hover_color", Color("009b88"))
	visibility_changed.connect(_focus_resume)


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box

func _focus_resume() -> void:
	if not visible:
		return
	
	await get_tree().process_frame
	if visible:
		$CenterContainer/Panel/Margin/Columns/Settings/ResumeButton.grab_focus()
