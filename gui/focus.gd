class_name Focus
# Where the keyboard and controller start on a screen: its first control that
# can take focus. It's given the focus unshown, so a mouse player never sees a
# focus ring; the ring shows once the d-pad, stick or arrows move it.


static func first(parent: Node) -> void:
	for control: Control in parent.find_children("*", "Control", true, false):
		var usable := not (control is BaseButton and (control as BaseButton).disabled)
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and usable:
			control.grab_focus(true)
			return
