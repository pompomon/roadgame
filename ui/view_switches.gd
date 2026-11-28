class_name ViewSwitches
extends RefCounted
## View-only arguments take precedence over the Web page's query (docs/PERF.md Q4, §5.1).


static func has(name: String, args: PackedStringArray, query: String) -> bool:
	return not _entry(name, args, query).is_empty()


static func value(name: String, args: PackedStringArray, query: String) -> String:
	var entry := _entry(name, args, query)
	var equals := entry.find("=")
	return entry.substr(equals + 1) if equals >= 0 else ""


static func page_query() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("location.search", true))


static func _entry(name: String, args: PackedStringArray, query: String) -> String:
	for arg: String in args:
		if arg == "--" + name or arg.begins_with("--" + name + "="):
			return arg.substr(2)
	for part: String in query.trim_prefix("?").split("&"):
		if part.get_slice("=", 0).replace("+", " ").uri_decode() == name:
			var equals := part.find("=")
			if equals < 0:
				return name
			return name + "=" + part.substr(equals + 1).replace("+", " ").uri_decode()
	return ""
