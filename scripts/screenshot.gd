class_name Screenshot
extends RefCounted



















const DIR := "user://screenshots"



const PREFIX := "screenshot"










static func capture(viewport: Viewport) -> String:
	if viewport == null:
		push_error("Screenshot: no viewport to capture")
		return ""

	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("Screenshot: viewport produced no image")
		return ""

	if not DirAccess.dir_exists_absolute(DIR):
		var err := DirAccess.make_dir_recursive_absolute(DIR)
		if err != OK:
			push_error("Screenshot: cannot create %s (error %d)" % [DIR, err])
			return ""

	var path := "%s/%s_%s.png" % [DIR, PREFIX, timestamp()]
	var save_err := image.save_png(path)
	if save_err != OK:
		push_error("Screenshot: failed to write %s (error %d)" % [path, save_err])
		return ""

	return ProjectSettings.globalize_path(path)




static func timestamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [
		t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"],
	]
