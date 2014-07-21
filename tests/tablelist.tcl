source ../juggle.tcl
package require tablelist

tablelist::tablelist .tbl -columns { 0 Test 0 Huhu }
.tbl insert 0 [list a b]
.tbl insert 0 [list c d]
button .save -text Speichern
pack .tbl .save
juggle::disable [list .save]
set group_id [juggle::onchange \
	[list .tbl] \
	{juggle::enable .save} \
	{} \
	{juggle::disable .save}]
