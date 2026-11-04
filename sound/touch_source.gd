extends RefCounted

## Each pointer owns its contact, so one finger releasing cannot silence another.

signal action_changed(action: StringName, pressed: bool, contact: String)
var contacts: Dictionary = {}

func press(pointer: int, action: StringName) -> void:
	if contacts.has(pointer):
		if contacts[pointer] == action:
			return
		release(pointer)
	if action.is_empty():
		return
	contacts[pointer] = action
	action_changed.emit(action, true, "touch_%d" % pointer)

func release(pointer: int) -> void:
	if not contacts.has(pointer):
		return
	var action: StringName = contacts[pointer]
	contacts.erase(pointer)
	action_changed.emit(action, false, "touch_%d" % pointer)

func clear() -> void:
	for pointer: int in contacts.keys():
		release(pointer)
