package diamond.policy.admin_test

import data.diamond.policy.admin
import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [],
			"sessions": [],
		},
		"bob": {
			"permissions": ["b07_admin"],
			"proposals": [],
			"sessions": [],
		},
		"carol": {
			"permissions": ["super_admin"],
			"proposals": [],
			"sessions": [],
		},
		"oscar": {
			"permissions": ["group_admin"],
			"proposals": [],
			"sessions": [],
		},
	},
	"sessions": {},
	"proposals": {},
	"beamlines": {},
	"admin": {"b07_admin": ["b07"], "group_admin": ["b07", "i07"]},
}

test_super_admin_subject if {
	admin.is_admin("carol") with data.diamond.data as diamond_data
}

test_beamline_admin_subject_beamline if {
	admin.is_beamline_admin("bob", "b07") with data.diamond.data as diamond_data
}

test_group_admin_subject_beamline if {
	admin.is_beamline_admin("oscar", "b07") with data.diamond.data as diamond_data
}

test_non_admin if {
	not admin.is_admin("alice") with data.diamond.data as diamond_data
}

test_beamline_admin_not_admin if {
	not admin.is_admin("bob") with data.diamond.data as diamond_data
}

test_non_beamline_admin if {
	not admin.is_beamline_admin("alice", "b07") with data.diamond.data as diamond_data
}

test_super_admin_not_beamline_admin if {
	not admin.is_beamline_admin("carol", "b07") with data.diamond.data as diamond_data
}
