class_name Logging

static func info(message: String) -> void:
	print("[%s] INFO - %s" % [Time.get_datetime_string_from_system(false, true), message] )

static func error(message: String) -> void:
	printerr("[%s] ERROR - %s" % [Time.get_datetime_string_from_system(false, true), message] )
