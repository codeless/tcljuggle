# juggle watches changes in widgets (input) and runs commands after a
# row of changes has been done
#
# Created on: 2011-05-02
# Author: MH
# Last update on: 2011-06-27
# Reason of last update: Added the FocusIn-Event to watch out for.
#
# ***
#
# juggle is aimed at GUI's and should make it possible to automatically
# run commands after the user modified input areas. For instance, juggle
# can be used to enable a "Save"-button once the user has provided some
# input to several fields.


package require Tcl	8.5
package require Tk	8.5


namespace eval ::juggle {
	namespace export enable disable onchange
	variable supported_classes [list \
		Entry \
		Mentry \
		Button \
		Checkbutton \
		Radiobutton \
		Listbox \
		TCombobox \
		Tablelist]
	variable last_group_id 0
	variable groups
}

proc ::juggle::enable { windows } {
	::juggle::process $windows { ::juggle::set_state normal }
}

proc ::juggle::disable { windows } {
	::juggle::process $windows { ::juggle::set_state disabled }
}

proc ::juggle::set_state { new_state window } {
	$window configure -state $new_state
}

proc ::juggle::onchange { 
	windows \
	completely_changed_command \
	partially_changed_command \
	reset_command } {

	variable last_group_id
	set rc 0

	# Create new group id
	incr last_group_id
	set group_id $last_group_id

	# Process list of windows
	if { [process $windows "add_to_group $group_id"] } {
		set rc $group_id

		# Save commands:
		variable groups
		dict set groups $group_id all_changed \
			$completely_changed_command 
		dict set groups $group_id partially_changed \
			$partially_changed_command 
		dict set groups $group_id reset \
			$reset_command 
	}

	return $rc
}

proc ::juggle::add_to_group { group_id widget } {
	variable groups

	# Get the value of the widget
	set value [::juggle::valueof $widget]

	# Save the value (initial value)
	dict set groups $group_id widgets $widget value $value
	dict set groups $group_id widgets $widget changed 0

	# Get notifications when the widget lost focus
	bind $widget <FocusOut> "+::juggle::lost_focus $group_id $widget"
	bind $widget <FocusIn> "+::juggle::lost_focus $group_id $widget"
}

proc ::juggle::lost_focus { group_id widget } {
	if { [::juggle::group_exists $group_id] } {
		set widgets [::juggle::get_widgets_in_group $group_id]
		if { [::juggle::is_widget_in_group $group_id $widget] } {
			::juggle::update $group_id $widget
		}
	}
}

proc ::juggle::group_exists { group_id } {
	variable groups
	return [dict exists $groups $group_id]
}

proc ::juggle::get_widgets_in_group { group_id } {
	variable groups
	return [dict keys [dict get $groups $group_id widgets] .*]
}

proc ::juggle::is_widget_in_group { group_id widget } {
	variable groups
	return [dict exists $groups $group_id widgets $widget]
}

proc ::juggle::update { group_id widget } {
	variable groups

	# Get current widget-value:
	set current_value [::juggle::valueof $widget]

	# If current value is different than the initial one
	if { $current_value eq [dict get $groups $group_id widgets $widget value] } {
		::juggle::unset_change_flag $group_id $widget
	} else {
		::juggle::set_change_flag $group_id $widget
	}
}

proc ::juggle::set_change_flag { group_id widget { flag 1 } } {
	variable groups

	if { [dict get $groups $group_id widgets $widget changed] != $flag } {
		dict set groups $group_id widgets $widget changed $flag
		update_group $group_id
	}
}

proc ::juggle::has_changed { group_id widget } {
	variable groups
	return [dict get $groups $group_id widgets $widget changed]
}

proc ::juggle::update_group { group_id } {
	# Get all widgets in the group
	set widgets [::juggle::get_widgets_in_group $group_id]

	# Reset count
	::juggle::reset_count $group_id

	# Count the changes
	::juggle::process $widgets "count_changes $group_id"
	set changes [::juggle::get_changes $group_id]

	# Get the number of widgets in the current group
	set number_of_widgets [::juggle::number_of_widgets $group_id]

	# If all widgets have been changed
	variable groups
	if { $number_of_widgets == $changes } {
		eval [dict get $groups $group_id all_changed]
	} elseif { $changes == 0 } {
		eval [dict get $groups $group_id partially_changed]
	} else {
		eval [dict get $groups $group_id reset]
	}
}

proc ::juggle::number_of_widgets { group_id } {
	set widgets [::juggle::get_widgets_in_group $group_id]
	return [llength $widgets]
}

proc ::juggle::get_changes { group_id } {
	variable groups
	return [dict get $groups $group_id count_changes]
}

proc ::juggle::set_changes { group_id value } {
	variable groups
	dict set groups $group_id count_changes $value
}

proc ::juggle::reset_count { group_id } {
	::juggle::set_changes $group_id 0
}

proc ::juggle::count_changes { group_id widget } {
	if { [::juggle::has_changed $group_id $widget] } {
		variable groups
		set count [::juggle::get_changes $group_id]
		incr count
		::juggle::set_changes $group_id $count
	}
}

proc ::juggle::unset_change_flag { group_id widget } {
	::juggle::set_change_flag $group_id $widget 0
}

proc ::juggle::valueof { widget } {
	set class [winfo class $widget]
	set rc 0

	switch $class {
		Checkbutton	{ set rc [::juggle::valueof_checkbutton $widget] }
		Radiobutton	{ set rc [::juggle::valueof_checkbutton $widget] }
		Listbox		{ set rc [::juggle::valueof_listbox $widget] }
		Tablelist	{ set rc [::juggle::valueof_listbox $widget] }
		Mentry		{ set rc [::juggle::valueof_mentry $widget] }
		default		{ set rc [::juggle::valueof_entry $widget] }
	}

	return $rc
}

proc ::juggle::valueof_mentry { widget } {
	return [eval $widget getstring]
}

proc ::juggle::valueof_entry { widget } {
	return [eval $widget get]
}

proc ::juggle::valueof_listbox { widget } {
	return [eval $widget curselection]
}

proc ::juggle::valueof_checkbutton { widget } {
	set associated_variable [$widget cget -variable]
	return [eval $associated_variable]
}

proc ::juggle::process { windows command } {
	# If at least one window has been passed
	if { [llength $windows] > 0} {
		# Get the first window
		set window [lindex $windows 0]

		if { [::juggle::exists $window] } {
			if { [::juggle::class_supported $window] } {
				# Run passed command
				eval $command $window
			} elseif { [::juggle::has_children $window] } {
				# Append children of "container" windows
				# e.g. frames
				lappend windows [winfo children $window]
				set windows [lsort -unique $windows]

				# Shift current window to the start
			}
		}

		# Remove the current window from the list
		set windows [lrange $windows 1 end]

		# If there are still windows to process
		if { [llength $windows] > 0 } {
			return [::juggle::process $windows $command]
		} else {
			return 1
		}
	}

	return 0
}

proc ::juggle::exists { window } {
	set rc 0

	if { [winfo exist $window] } {
		set rc 1
	} else {
		::juggle::report_error \
			"The window $window does not exist"
	}

	return $rc
}

proc ::juggle::class_supported { window } {
	variable supported_classes
	set rc 0
	set window_class [winfo class $window]

	if { [lsearch $supported_classes $window_class] >= 0} {
		set rc 1
	}

	return $rc
}

proc ::juggle::report_error { message } {
	bgerror $message
}

proc ::juggle::has_children { window } {
	set rc 0

	set children [winfo children $window]
	if { [llength $children] > 0 } {
		set rc 1
	}

	return $rc
}
