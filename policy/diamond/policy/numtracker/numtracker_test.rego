package diamond.policy.numtracker_test

import data.diamond.policy.numtracker
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
		"desmond": {
			"permissions": [],
			"proposals": [2],
			"sessions": [13],
		},
		"edna": {
			"permissions": [],
			"proposals": [2],
			"sessions": [13, 14],
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
		"13": {
			"beamline": "b07",
			"proposal_number": 2,
			"visit_number": 1,
		},
		"14": {
			"beamline": "b07",
			"proposal_number": 2,
			"visit_number": 2,
		},
	},
	"proposals": {
		"1": {"sessions": {
			"1": 11,
			"2": 12,
		}},
		"2": {"sessions": {
			"1": 13,
			"2": 14,
		}},
	},
	"beamlines": {"i03": {"sessions": [11]}, "b07": {"sessions": [12, 13, 14]}},
	"admin": {"b07_admin": ["b07"]},
}

# service account UDC path

test_write_to_beamline_visit_service_account if {
	numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_write_to_beamline_visit_service_account_wrong_beamline if {
	not numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"beamline": "b07"}
}

test_write_to_beamline_visit_service_account_nonexistent_beamline if {
	not numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"beamline": "i99"}
}

# user fedid path

test_write_to_beamline_visit_user if {
	numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "b07", "proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_write_to_beamline_visit_user_no_access if {
	not numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_write_to_beamline_visit_user_wrong_beamline if {
	not numtracker.write_to_beamline_visit with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}
