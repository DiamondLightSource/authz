package diamond.policy.beamline_test

import data.diamond.policy.beamline
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

test_user_beamlines_super_admin if {
	beamline.user_beamlines == {"i03", "b07"} with data.diamond.policy.token.claims as {"fedid": "carol"}
		with data.diamond.data as diamond_data
}

test_user_beamlines_beamline_admin if {
	beamline.user_beamlines == {"b07"} with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_user_beamlines_non_admin if {
	beamline.user_beamlines == set() with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_user_beamlines_service_account if {
	beamline.user_beamlines == {"b07"} with data.diamond.policy.token.claims as {"beamline": "b07"}
		with data.diamond.data as diamond_data
}

test_user_beamlines_service_account_bad_beamline_claim if {
	beamline.user_beamlines == set() with data.diamond.policy.token.claims as {"beamline": "area-51-beamline"}
		with data.diamond.data as diamond_data
}
