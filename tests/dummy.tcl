source ../juggle.tcl

entry .e1
entry .e2
button .b -text "Button"
pack .e1 .e2 .b
juggle::disable [list .b]

set group_id [juggle::onchange \
	[list .e1 .e2] \
	{juggle::enable .b} \
	{} \
	{juggle::disable .b}]
puts $group_id
