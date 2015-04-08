package ifneeded juggle 0.5 {
		source [file join {@} juggle.tcl]
		namespace eval ::juggle {
			namespace ensemble create
		}
		package provide juggle	0.5
	}
