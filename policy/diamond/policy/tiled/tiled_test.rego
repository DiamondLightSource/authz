package diamond.policy.tiled_test

import data.diamond.policy.tiled
import rego.v1

test_default_no_scopes if {
	tiled.scopes == set()
}

test_wrong_azp_read_scopes if {
	tiled.scopes == tiled.read_scopes with data.diamond.policy.token.claims as {}
	tiled.scopes == tiled.read_scopes with data.diamond.policy.token.claims as {"sub": "foo"}
	tiled.scopes == tiled.read_scopes with data.diamond.policy.token.claims as {"azp": "foo"}
}

test_blueapi_given_write_scopes if {
	tiled.scopes == {
		"read:metadata",
		"read:data",
		"write:metadata",
		"write:data",
		"create",
		"register",
	} with data.diamond.policy.token.claims as {"azp": "foo-blueapi"}
}

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

test_user_session_tags if {
	tiled.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
	tiled.user_sessions == {
		`{"proposal": 1, "visit": 2, "beamline": "b07"}`,
		`{"proposal": 1, "visit": 1, "beamline": "i03"}`,
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}
	tiled.user_sessions == {
		`{"proposal": 1, "visit": 2, "beamline": "b07"}`,
		`{"proposal": 1, "visit": 1, "beamline": "i03"}`,
		`{"proposal": 2, "visit": 1, "beamline": "b07"}`,
		`{"proposal": 2, "visit": 2, "beamline": "b07"}`,
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "bob"}
	tiled.user_sessions == {
		`{"proposal": 1, "visit": 2, "beamline": "b07"}`,
		`{"proposal": 1, "visit": 1, "beamline": "i03"}`,
		`{"proposal": 2, "visit": 1, "beamline": "b07"}`,
		`{"proposal": 2, "visit": 2, "beamline": "b07"}`,
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
	tiled.user_sessions == {
		`{"proposal": 2, "visit": 1, "beamline": "b07"}`,
		`{"proposal": 2, "visit": 2, "beamline": "b07"}`,
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "desmond"}
	tiled.user_sessions == {
		`{"proposal": 2, "visit": 1, "beamline": "b07"}`,
		`{"proposal": 2, "visit": 2, "beamline": "b07"}`,
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "edna"}
}
