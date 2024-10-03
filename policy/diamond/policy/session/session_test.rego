package diamond.policy.session_test

import data.diamond.policy.session
import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [1],
			"sessions": [],
		},
		"bob": {
			"permissions": ["b07_admin"],
			"proposals": [],
			"sessions": [11],
		},
		"carol": {
			"permissions": ["super_admin"],
			"proposals": [],
			"sessions": [],
		},
		"oscar": {
			"permissions": [],
			"proposals": [],
			"sessions": [],
		},
	},
	"sessions": {
		"11": {
			"beamline": "i03",
			"proposal_number": 1,
			"visit_number": 1,
		},
		"12": {
			"beamline": "b07",
			"proposal_number": 1,
			"visit_number": 2,
		},
	},
	"proposals": {"1": {"sessions": {
		"1": 11,
		"2": 12,
	}}},
	"beamlines": {"i03": {"sessions": [11]}, "b07": {"sessions": [12]}},
	"admin": {"b07_admin": ["b07"]},
}

test_session_member_allowed if {
	session.access_session("bob", 1, 1) with data.diamond.data as diamond_data
}

test_proposal_member_allowed if {
	session.access_session("alice", 1, 1) with data.diamond.data as diamond_data
}

test_beamline_admin_allowed if {
	session.access_session("bob", 1, 2) with data.diamond.data as diamond_data
}

test_super_admin_allowed if {
	session.access_session("carol", 1, 2) with data.diamond.data as diamond_data
}

test_non_member_denied if {
	not session.access_session("oscar", 1, 1) with data.diamond.data as diamond_data
}

test_admin_not_on_session if {
	not session.on_session("carol", 1, 1) with data.diamond.data as diamond_data
}
