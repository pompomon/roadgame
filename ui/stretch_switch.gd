class_name StretchSwitch
extends RefCounted


static func mode(value: String, project_mode: Window.ContentScaleMode) -> Window.ContentScaleMode:
	match value:
		"canvas_items":
			return Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		"viewport":
			return Window.CONTENT_SCALE_MODE_VIEWPORT
		_:
			return project_mode
